import Foundation
import MeetingDataKit

public protocol LocalEntityDetector {
    func detect(in text: String, language: String) async throws -> [IdentifyingSpan]
}

public enum DeidentificationService {
    public static func makeDraft<D: LocalEntityDetector>(
        transcript: Transcript, detector: D
    ) async throws -> AnalysisTextDraft {
        let text = transcript.text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeidentificationError.emptyText
        }
        let modelSpans = try await detector.detect(in: text, language: transcript.language)
        let ruleSpans = try IdentityRules.detect(in: text)
        let merged = try IdentitySpans.validated(modelSpans + ruleSpans, in: text)
        let redacted = try IdentitySpans.replacing(merged, in: text)
        return AnalysisTextDraft(language: transcript.language,
                                 redactedText: redacted, replacementCount: merged.count)
    }

    public static func approve<D: LocalEntityDetector>(
        draft: AnalysisTextDraft, reviewedText: String, detector: D
    ) async throws -> AnalysisTextArtifact {
        guard !reviewedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeidentificationError.emptyText
        }
        let modelSpans = try await detector.detect(in: reviewedText, language: draft.language)
        let ruleSpans = try IdentityRules.detect(in: reviewedText)
        guard try IdentitySpans.validated(modelSpans + ruleSpans, in: reviewedText).isEmpty else {
            throw DeidentificationError.residualIdentifier
        }
        return AnalysisTextArtifact(language: draft.language, text: reviewedText)
    }
}
