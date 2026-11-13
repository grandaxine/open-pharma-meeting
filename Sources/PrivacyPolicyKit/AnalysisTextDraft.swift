import Foundation

public struct AnalysisTextDraft: Sendable {
    public let language: String
    public let redactedText: String
    public let replacementCount: Int

    init(language: String, redactedText: String, replacementCount: Int) {
        self.language = language
        self.redactedText = redactedText
        self.replacementCount = replacementCount
    }
}

public struct AnalysisTextArtifact: Encodable, Sendable {
    public let schemaVersion: String
    public let language: String
    public let text: String

    init(language: String, text: String) {
        self.schemaVersion = "0.1"
        self.language = language
        self.text = text
    }

    enum CodingKeys: String, CodingKey { case schemaVersion, language, text }
}
