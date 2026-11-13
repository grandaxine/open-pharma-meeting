import Foundation

public enum SpeechFailure: Equatable {
    case siriOrDictationDisabled
    case assetsMissing

    public static func classify(_ error: Error) -> SpeechFailure? {
        let nsError = error as NSError
        guard nsError.domain == "kLSRErrorDomain" else { return nil }
        switch nsError.code {
        case 201: return .siriOrDictationDisabled
        case 102: return .assetsMissing
        default: return nil
        }
    }
}
