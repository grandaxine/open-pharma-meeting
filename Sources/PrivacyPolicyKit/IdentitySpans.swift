import Foundation

public enum IdentityKind: String, Sendable {
    case doctor, patient, person, address, organization, contact, document, other

    var placeholderName: String {
        switch self {
        case .doctor: return "DOCTOR"
        case .patient: return "PATIENT"
        case .person: return "PERSON"
        case .address: return "ADDRESS"
        case .organization: return "ORGANIZATION"
        case .contact: return "CONTACT"
        case .document: return "DOCUMENT"
        case .other: return "IDENTIFIER"
        }
    }
}

public struct IdentifyingSpan: Equatable, Sendable {
    public let startUTF16: Int
    public let endUTF16: Int
    public let kind: IdentityKind

    public init(startUTF16: Int, endUTF16: Int, kind: IdentityKind) {
        self.startUTF16 = startUTF16
        self.endUTF16 = endUTF16
        self.kind = kind
    }
}

public enum DeidentificationError: Error, Equatable {
    case invalidSpan
    case conflictingSpans
    case residualIdentifier
    case emptyText
}

enum IdentitySpans {
    static func validated(_ spans: [IdentifyingSpan], in text: String) throws -> [IdentifyingSpan] {
        let sorted = spans.sorted {
            if $0.startUTF16 != $1.startUTF16 { return $0.startUTF16 < $1.startUTF16 }
            return $0.endUTF16 > $1.endUTF16
        }
        var merged: [IdentifyingSpan] = []
        for span in sorted {
            guard span.startUTF16 >= 0, span.endUTF16 > span.startUTF16,
                  span.endUTF16 <= text.utf16.count,
                  let range = Range(NSRange(location: span.startUTF16,
                                            length: span.endUTF16 - span.startUTF16), in: text),
                  !text[range].isEmpty else { throw DeidentificationError.invalidSpan }
            // String.Index can point inside an extended grapheme cluster. Only full
            // Character boundaries may be replaced without damaging the source.
            guard text.indices.contains(range.lowerBound),
                  range.upperBound == text.endIndex || text.indices.contains(range.upperBound) else {
                throw DeidentificationError.invalidSpan
            }
            if let last = merged.last, span.startUTF16 < last.endUTF16 {
                guard span.kind == last.kind else { throw DeidentificationError.conflictingSpans }
                merged[merged.count - 1] = IdentifyingSpan(
                    startUTF16: last.startUTF16,
                    endUTF16: max(last.endUTF16, span.endUTF16), kind: last.kind)
            } else {
                merged.append(span)
            }
        }
        return merged
    }

    static func replacing(_ spans: [IdentifyingSpan], in text: String) throws -> String {
        let spans = try validated(spans, in: text)
        var replacements: [(NSRange, String)] = []
        var numbers: [IdentityKind: Int] = [:]
        var aliases: [String: String] = [:]
        let source = text as NSString
        for span in spans {
            let range = NSRange(location: span.startUTF16, length: span.endUTF16 - span.startUTF16)
            let original = source.substring(with: range)
            let key = "\(span.kind.rawValue):\(original.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil))"
            let replacement: String
            if let existing = aliases[key] {
                replacement = existing
            } else {
                numbers[span.kind, default: 0] += 1
                replacement = "[\(span.kind.placeholderName)_\(numbers[span.kind]!)]"
                aliases[key] = replacement
            }
            replacements.append((range, replacement))
        }
        let result = NSMutableString(string: text)
        for (range, replacement) in replacements.reversed() {
            result.replaceCharacters(in: range, with: replacement)
        }
        return result as String
    }
}
