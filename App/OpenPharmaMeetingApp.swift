import SwiftUI
import UniformTypeIdentifiers
import MeetingDataKit
import MeetingCaptureKit
import TranscriptionKit

@main struct OpenPharmaMeetingApp: App {
    var body: some Scene { WindowGroup { MeetingView() } }
}
struct MeetingDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
@MainActor struct MeetingView: View {
    @StateObject private var recorder = NativeAudioRecorder()
    @State private var repository: LocalMeetingRepository?
    @State private var meetings: [Meeting] = []
    @State private var selection: UUID?
    @State private var language = "en-US"
    @State private var notice: String?
    @State private var consent = false
    @State private var busy = false
    @State private var progress = 0.0
    @State private var transcription: Task<Void, Never>?
    @State private var export = false
    @State private var importing = false
    @State private var document = MeetingDocument()
    private var selected: Meeting? { meetings.first { $0.id == selection } }
    private var active: Bool { recorder.meeting != nil }
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(meetings) { m in
                    VStack(alignment: .leading) {
                        Text(m.title)
                        Text(m.recording.state.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                    }.tag(m.id)
                }
            }
            .navigationTitle("Meetings")
            .toolbar { Button("Import JSON") { importing = true }.disabled(active || busy) }
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Open Pharma Meeting").font(.largeTitle.bold())
                    Label("Local only · Private by default", systemImage: "lock.shield")
                    Picker("Language", selection: $language) {
                        Text("English (US)").tag("en-US")
                        Text("Русский").tag("ru-RU")
                        Text("Deutsch").tag("de-DE")
                    }.disabled(active || busy)
                    Text("Offline recognition availability depends on the language and installed on-device assets. Unsupported recognition never uses a remote fallback.").font(.footnote)
                    if active {
                        Label(recorder.meeting?.recording.state == .paused ? "Paused" : "Recording", systemImage: "mic.fill").foregroundStyle(.red)
                        Text(Duration.seconds(recorder.elapsed).formatted(.time(pattern: .hourMinuteSecond)))
                        HStack {
                            Button(recorder.meeting?.recording.state == .paused ? "Resume" : "Pause") {
                                perform { if recorder.meeting?.recording.state == .paused { try recorder.resume() } else { try recorder.pause() } }
                            }
                            Button("Stop and save") { perform { let m = try recorder.stop(); selection = m.id; try reload() } }
                        }
                    } else {
                        Button("Record meeting") { consent = true }.buttonStyle(.borderedProminent).disabled(busy || repository == nil)
                    }
                    if let m = selected {
                        Divider()
                        Text(m.title).font(.title2)
                        Text(m.createdAt, style: .date)
                        Text("Audio: \(String(format: "%.0f", m.recording.duration)) seconds · \(m.recording.chunks.count) completed chunks")
                        if m.recording.state == .interrupted {
                            Text("Recording was interrupted. Completed chunks are retained. Recovery may restore readable pending audio; missing samples cannot be reconstructed.")
                            if m.recording.pendingFilename != nil {
                                Button("Recover pending audio") { perform { guard let repository else { return }; _ = try AudioIntegrity.recover(m, repository: repository); try reload() } }.disabled(busy || active)
                            }
                        }
                        Button("Transcribe on this iPad") { transcribe(m) }.disabled(active || busy || m.recording.chunks.isEmpty)
                        if busy { ProgressView(value: progress); Button("Cancel transcription") { transcription?.cancel() } }
                        if let t = m.transcript {
                            ForEach(t.segments) { s in
                                HStack(alignment: .top) { Text(String(format: "%.1fs", s.start)).monospacedDigit().foregroundStyle(.secondary); Text(s.text).textSelection(.enabled) }
                            }
                        }
                        Text("Export discloses the transcript and metadata to your chosen destination, outside this app's protection. Audio is not included.").font(.footnote)
                        Button("Export meeting JSON…") { perform { document = MeetingDocument(data: try MeetingCodec.encode(m)); export = true } }.disabled(active || busy)
                        Button("Delete local meeting", role: .destructive) { perform { try repository?.delete(m.id); selection = nil; try reload() } }.disabled(active || busy)
                    }
                    if let notice { Text(notice).foregroundStyle(.orange).accessibilityLabel("Status: " + notice) }
                    if let message = recorder.errorMessage { Text(message).foregroundStyle(.orange) }
                }.padding(28).frame(maxWidth: 850, alignment: .leading)
            }.navigationTitle("Local recorder")
        }
        .task {
            guard repository == nil else { return }
            perform {
                let store = try LocalMeetingRepository(); repository = store
                _ = try store.recoverInterrupted()
                try reload()
            }
        }
        .onChange(of: recorder.meeting?.id) { _ in if !active { perform { try reload() } } }
        .confirmationDialog("Participant consent", isPresented: $consent, titleVisibility: .visible) {
            Button("I have obtained the required consent — record") { start() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Inform everyone before recording and follow your company's consent and retention procedures. Audio and transcripts stay on this iPad.") }
        .fileExporter(isPresented: $export, document: document, contentType: .json, defaultFilename: "meeting") { result in
            if case .failure = result { notice = "Export failed." }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            perform {
                let url = try result.get(); let granted = url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
                guard bytes <= MeetingCodec.maximumBytes else { throw ContractError.invalid("Import too large") }
                guard let repository else { return }
                let m = try repository.importMeeting(Data(contentsOf: url)); selection = m.id; try reload()
                notice = "Metadata imported. Referenced audio files are not part of a JSON import."
            }
        }
    }
    private func perform(_ action: () throws -> Void) { do { try action() } catch { notice = String(describing: error) } }
    private func reload() throws {
        guard let repository else { return }
        let result = try repository.list(); meetings = result.meetings
        if !result.unreadableFiles.isEmpty { notice = "Some records could not be read. They remain on disk; no data was silently deleted." }
    }
    private func start() {
        guard let repository, !busy, !active else { return }
        busy = true
        var m = Meeting(title: "Meeting " + Date().formatted(date: .abbreviated, time: .shortened), language: language)
        m.consentAcknowledgedAt = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        Task { @MainActor in
            defer { busy = false }
            do { try await recorder.start(m, repository: repository); selection = m.id; try reload() }
            catch { notice = String(describing: error); try? reload() }
        }
    }
    private func transcribe(_ m: Meeting) {
        guard let repository else { return }
        busy = true; progress = 0; notice = nil
        transcription = Task { @MainActor in
            defer { busy = false; transcription = nil }
            do {
                let t = try await AppleSpeechEngine().transcribe(meeting: m, repository: repository) { value in Task { @MainActor in progress = value } }
                try Task.checkCancellation()
                var updated = try repository.load(m.id); updated.transcript = t; try repository.save(updated); try reload()
            } catch is CancellationError { notice = "Transcription cancelled; prior data retained." }
            catch { notice = String(describing: error) }
        }
    }
}
