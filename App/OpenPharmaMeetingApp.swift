import SwiftUI
import UniformTypeIdentifiers
import MeetingDataKit
import MeetingCaptureKit
import TranscriptionKit
import PrivacyPolicyKit

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
    @State private var language = "ru-RU"
    @State private var notice: String?
    @State private var consent = false
    @State private var busy = false
    @State private var progress = 0.0
    @State private var transcription: Task<Void, Never>?
    @State private var export = false
    @State private var importing = false
    @State private var modelImporting = false
    @State private var activeModel = LocalModelStore.activeProfile
    @State private var installedModels = Set(LocalModelStore.installedProfiles)
    @State private var importTarget: LocalModelProfile = .qwen
    @State private var modelError: String?
    @State private var analysisError: String?
    @State private var modelImportTask: Task<Void, Never>?
    @State private var reviewOpen = false
    @State private var reviewDraft: AnalysisTextDraft?
    @State private var reviewDetector: LocalLlamaEntityDetector?
    @State private var reviewSource = ""
    @State private var analysisTask: Task<Void, Never>?
    @State private var document = MeetingDocument()
    private var selected: Meeting? { meetings.first { $0.id == selection } }
    private var active: Bool { recorder.meeting != nil }
    private var modelReady: Bool { installedModels.contains(activeModel) }
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(meetings) { m in
                    VStack(alignment: .leading) {
                        Text(m.title)
                        Text(stateTitle(m.recording.state)).font(.caption).foregroundStyle(.secondary)
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
                    Picker("Recognition language", selection: $language) {
                        Text("English (US)").tag("en-US")
                        Text("Русский").tag("ru-RU")
                        Text("Deutsch").tag("de-DE")
                    }.disabled(active || busy)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Local text model").font(.headline)
                        ForEach(LocalModelProfile.allCases, id: \.id) { profile in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(verbatim: profile.displayName)
                                    if installedModels.contains(profile) {
                                        Text("Installed on this iPad").font(.caption).foregroundStyle(.secondary)
                                    } else {
                                        Text("Not installed").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Link("Verified model file", destination: profile.sourceURL)
                                        .font(.caption)
                                }
                                Spacer()
                                if installedModels.contains(profile) && activeModel != profile {
                                    Button("Use model") {
                                        do { try LocalModelStore.select(profile); activeModel = profile; modelError = nil }
                                        catch { modelError = modelMessage(for: error) }
                                    }.disabled(active || busy)
                                }
                                if activeModel == profile && installedModels.contains(profile) {
                                    Label("Active", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                Button {
                                    importTarget = profile
                                    modelError = nil
                                    modelImporting = true
                                } label: {
                                    if installedModels.contains(profile) { Text("Replace…") }
                                    else { Text("Import…") }
                                }.disabled(active || busy)
                            }
                        }
                        Text(String(format: NSLocalizedString("App version %@ (%@)", comment: "Version and build"),
                                    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
                                    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))
                            .font(.caption).foregroundStyle(.secondary)
                        if let modelError { Text(modelError).foregroundStyle(.orange) }
                    }
                    if modelImportTask != nil {
                        ProgressView("Importing and verifying model on this iPad…")
                        Button("Cancel model import") { modelImportTask?.cancel() }
                    }
                    Label {
                        Text("Speech recognition runs only on this iPad. Turn on Siri in Settings → Siri (or Apple Intelligence & Siri), and enable Dictation in Settings → General → Keyboard. If your organization restricts these settings, contact IT. Audio remains saved if recognition fails.")
                    } icon: {
                        Image(systemName: "info.circle.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
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
                        Text(String(format: NSLocalizedString("Audio: %.0f seconds · %d completed chunks", comment: "Meeting audio summary"), m.recording.duration, m.recording.chunks.count))
                        if m.recording.state == .interrupted {
                            Text("Recording was interrupted. Completed chunks are retained. Recovery may restore readable pending audio; missing samples cannot be reconstructed.")
                            if m.recording.pendingFilename != nil {
                                Button("Recover pending audio") { perform { guard let repository else { return }; _ = try AudioIntegrity.recover(m, repository: repository); try reload() } }.disabled(busy || active)
                            }
                        }
                        Button {
                            transcribe(m)
                        } label: {
                            Label("Transcribe on this iPad", systemImage: "waveform")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .controlSize(.large)
                        .disabled(active || busy || m.recording.chunks.isEmpty)
                        if busy { ProgressView(value: progress); Button("Cancel transcription") { transcription?.cancel() } }
                        Text("Export discloses the transcript and metadata to your chosen destination, outside this app's protection. Audio is not included.").font(.footnote)
                        Button("Export raw meeting JSON…") { perform { document = MeetingDocument(data: try MeetingCodec.encode(m)); export = true } }.disabled(active || busy)
                        if let t = m.transcript {
                            Button {
                                beginReview(t)
                            } label: {
                                Label("De-identify text on this iPad…", systemImage: "person.crop.circle.badge.checkmark")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(active || busy || !modelReady)
                            if modelReady {
                                Text(String(format: NSLocalizedString("Active model: %@", comment: "Selected local model"),
                                            activeModel.displayName))
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            if let analysisError { Text(analysisError).foregroundStyle(.orange) }
                            if busy && analysisTask != nil {
                                Button("Cancel de-identification") { analysisTask?.cancel() }
                            }
                            if !modelReady {
                                Text("Import a verified local model to enable de-identification.")
                                    .font(.footnote)
                            }
                            let paragraphs = t.paragraphs()
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(paragraphs.indices, id: \.self) { index in
                                    Text(verbatim: paragraphs[index]).textSelection(.enabled)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button("Delete local meeting", role: .destructive) { perform { try repository?.delete(m.id); selection = nil; try reload() } }.disabled(active || busy)
                    }
                    if let notice { Text(notice).foregroundStyle(.orange).accessibilityLabel(String(localized: "Status: ") + notice) }
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
            if case .failure = result { notice = String(localized: "Export failed.") }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            perform {
                let url = try result.get(); let granted = url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
                guard bytes <= MeetingCodec.maximumBytes else { throw ContractError.invalid("Import too large") }
                guard let repository else { return }
                let m = try repository.importMeeting(Data(contentsOf: url)); selection = m.id; try reload()
                notice = String(localized: "Metadata imported. Referenced audio files are not part of a JSON import.")
            }
        }
        .fileImporter(isPresented: $modelImporting, allowedContentTypes: [.item]) { result in
            do {
                let source = try result.get()
                let target = importTarget
                busy = true
                modelImportTask = Task { @MainActor in
                    defer { busy = false; modelImportTask = nil }
                    let worker = Task.detached(priority: .userInitiated) {
                        try LocalModelStore.importApprovedModel(from: source, as: target)
                    }
                    do {
                        try await withTaskCancellationHandler {
                            try await worker.value
                        } onCancel: {
                            worker.cancel()
                        }
                        try Task.checkCancellation()
                        try LocalModelStore.select(target)
                        installedModels = Set(LocalModelStore.installedProfiles)
                        activeModel = target
                        modelError = nil
                    } catch is CancellationError {
                        modelError = String(localized: "Model import cancelled.")
                    } catch {
                        modelError = modelMessage(for: error)
                    }
                }
            } catch {
                modelError = String(localized: "Model import cancelled.")
            }
        }
        .sheet(isPresented: $reviewOpen, onDismiss: {
            reviewDraft = nil
            reviewDetector = nil
            reviewSource = ""
        }) {
            if let reviewDraft, let reviewDetector {
                DeidentificationReviewView(sourceText: reviewSource, draft: reviewDraft,
                                           detector: reviewDetector,
                                           modelName: activeModel.displayName) { reviewOpen = false }
            }
        }
    }
    private func perform(_ action: () throws -> Void) { do { try action() } catch { notice = String(describing: error) } }
    private func stateTitle(_ state: RecordingState) -> LocalizedStringKey {
        switch state {
        case .ready: return "Ready"
        case .recording: return "Recording"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .interrupted: return "Interrupted"
        }
    }
    private func transcriptionMessage(for error: Error) -> String {
        switch SpeechFailure.classify(error) {
        case .siriOrDictationDisabled:
            return String(localized: "Speech service is disabled. Turn on Siri in Settings → Siri (or Apple Intelligence & Siri). Check Dictation in Settings → General → Keyboard. If a setting is unavailable, contact IT. Audio remains saved.")
        case .assetsMissing:
            return String(localized: "The on-device speech package for this language is missing. Install the language assets in iPad settings or choose another supported language. Audio remains saved.")
        case nil:
            return String(describing: error)
        }
    }
    private func reload() throws {
        guard let repository else { return }
        let result = try repository.list(); meetings = result.meetings
        if !result.unreadableFiles.isEmpty { notice = String(localized: "Some records could not be read. They remain on disk; no data was silently deleted.") }
    }
    private func start() {
        guard let repository, !busy, !active else { return }
        busy = true
        var m = Meeting(title: String(localized: "Meeting") + " " + Date().formatted(date: .abbreviated, time: .shortened), language: language)
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
            } catch is CancellationError { notice = String(localized: "Transcription cancelled; prior data retained.") }
            catch { notice = transcriptionMessage(for: error) }
        }
    }

    private func beginReview(_ transcript: Transcript) {
        guard !busy else { return }
        busy = true
        analysisError = nil
        let profile = activeModel
        analysisTask = Task { @MainActor in
            defer { busy = false; analysisTask = nil }
            do {
                let worker = Task.detached(priority: .userInitiated) {
                    try LocalModelStore.verifiedModelURL(for: profile)
                }
                let modelURL = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                try Task.checkCancellation()
                let detector = LocalLlamaEntityDetector(modelURL: modelURL, profile: profile)
                let draft = try await DeidentificationService.makeDraft(transcript: transcript,
                                                                        detector: detector)
                try Task.checkCancellation()
                reviewSource = transcript.text
                reviewDraft = draft
                reviewDetector = detector
                reviewOpen = true
            } catch is CancellationError {
                analysisError = String(localized: "Local de-identification cancelled; no text was exported.")
            } catch {
                analysisError = modelMessage(for: error)
            }
        }
    }

    private func modelMessage(for error: Error) -> String {
        if let integrity = error as? ModelIntegrityError {
            switch integrity {
            case .hashMismatch: return String(localized: "This GGUF differs from the approved model file. Choose the listed model and quantization.")
            case .invalidExpectedHash: return String(localized: "The app's model verification data is invalid.")
            }
        }
        if let store = error as? LocalModelStoreError, case .notInstalled = store {
            return String(localized: "The selected model is not installed on this iPad.")
        }
        if let inference = error as? LocalInferenceError {
            switch inference {
            case .modelLoadFailed, .contextLoadFailed:
                return String(localized: "The model could not load. Check available memory and try again; no text was exported.")
            case .promptTooLong, .outputTooLong:
                return String(localized: "The model could not finish this text. Try a shorter meeting; no text was exported.")
            case .decodeFailed, .invalidUTF8:
                return String(localized: "The model returned an unreadable result. Try again or switch models; no text was exported.")
            }
        }
        if error is EntityResponseError || error is DeidentificationError {
            return String(localized: "The model result did not pass the local safety check. Review the transcript or switch models; no text was exported.")
        }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError {
            return String(localized: "There is not enough free space to import this model.")
        }
        return String(localized: "The local operation failed. Check the model file and free space; no text was exported.")
    }
}
