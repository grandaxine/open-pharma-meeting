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
    let modelName: String
    let dismiss: () -> Void

    @State private var reviewedText: String
    @State private var checking = false
    @State private var approvalTask: Task<Void, Never>?
    @State private var export = false
    @State private var document = AnalysisTextDocument(text: "")
    @State private var error: String?

    init(sourceText: String, draft: AnalysisTextDraft,
         detector: LocalLlamaEntityDetector, modelName: String,
         dismiss: @escaping () -> Void) {
        self.sourceText = sourceText
        self.draft = draft
        self.detector = detector
        self.modelName = modelName
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
                    Text(String(format: NSLocalizedString("Active model: %@", comment: "Selected local model"), modelName))
                        .font(.subheadline).foregroundStyle(.secondary)
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
                            } catch is CancellationError {
                                self.error = String(localized: "Final check cancelled; no text was exported.")
                            } catch {
                                self.error = reviewMessage(for: error)
                            }
                        }
                    } label: {
                        Label("Approve text and export…", systemImage: "checkmark.shield")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(checking || reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if checking { ProgressView("Checking text on this iPad…") }
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading) {
                            Text("Original transcript — local only").font(.headline)
                            Text(verbatim: sourceText).textSelection(.enabled)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading) {
                            Text("Text proposed for export").font(.headline)
                            TextEditor(text: $reviewedText).frame(minHeight: 320)
                                .disabled(checking)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary))
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(24)
            }
            .navigationTitle("Review de-identified text")
            .safeAreaInset(edge: .top) {
                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial)
                }
            }
            .toolbar { Button("Close") { approvalTask?.cancel(); dismiss() } }
            .onDisappear { approvalTask?.cancel() }
            .fileExporter(isPresented: $export, document: document, contentType: .plainText,
                          defaultFilename: "meeting-analysis-text") { result in
                if case .failure = result { error = String(localized: "Text export failed.") }
            }
        }
    }

    private func reviewMessage(for error: Error) -> String {
        if let failure = error as? DeidentificationError {
            switch failure {
            case .residualIdentifier: return String(localized: "A doctor or patient identifier is still present. Edit the proposed text before export.")
            case .emptyText: return String(localized: "The export text is empty.")
            case .invalidSpan, .conflictingSpans:
                return String(localized: "The model returned conflicting text spans. Switch models or retry; no text was exported.")
            }
        }
        if error is EntityResponseError || error is LocalInferenceError {
            return String(localized: "The model could not complete the final check. Switch models or retry; no text was exported.")
        }
        return String(localized: "Final local check failed. Review names and contact details, then try again.")
    }
}
