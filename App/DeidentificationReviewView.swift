import SwiftUI
import UniformTypeIdentifiers
import PrivacyPolicyKit

struct AnalysisTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct DeidentificationReviewView: View {
    let sourceText: String
    let draft: AnalysisTextDraft
    let detector: LocalLlamaEntityDetector
    let dismiss: () -> Void

    @State private var reviewedText: String
    @State private var checking = false
    @State private var approvalTask: Task<Void, Never>?
    @State private var export = false
    @State private var document = AnalysisTextDocument(text: "")
    @State private var error: String?

    init(sourceText: String, draft: AnalysisTextDraft,
         detector: LocalLlamaEntityDetector, dismiss: @escaping () -> Void) {
        self.sourceText = sourceText
        self.draft = draft
        self.detector = detector
        self.dismiss = dismiss
        _reviewedText = State(initialValue: draft.redactedText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Review every identifier before export. Model output can miss names or remove a brand. Only the approved text will be exported; the original audio and transcript stay on this iPad.")
                        .font(.subheadline)
                    Text("Suggested replacements: \(draft.replacementCount)").font(.subheadline.bold())
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading) {
                            Text("Original transcript — local only").font(.headline)
                            Text(verbatim: sourceText).textSelection(.enabled)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading) {
                            Text("Text proposed for export").font(.headline)
                            TextEditor(text: $reviewedText).frame(minHeight: 320)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary))
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                    Button {
                        checking = true
                        error = nil
                        approvalTask = Task { @MainActor in
                            defer { checking = false; approvalTask = nil }
                            do {
                                let artifact = try await DeidentificationService.approve(
                                    draft: draft, reviewedText: reviewedText, detector: detector)
                                try Task.checkCancellation()
                                document = AnalysisTextDocument(text: artifact.text)
                                export = true
                            } catch {
                                self.error = String(localized: "Final local check failed. Review names and contact details, then try again.")
                            }
                        }
                    } label: {
                        Label("Approve text and export…", systemImage: "checkmark.shield")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(checking || reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if checking { ProgressView("Checking text on this iPad…") }
                }.padding(24)
            }
            .navigationTitle("Review de-identified text")
            .toolbar { Button("Close") { approvalTask?.cancel(); dismiss() } }
            .onDisappear { approvalTask?.cancel() }
            .fileExporter(isPresented: $export, document: document, contentType: .plainText,
                          defaultFilename: "meeting-analysis-text") { result in
                if case .failure = result { error = String(localized: "Text export failed.") }
            }
        }
    }
}
