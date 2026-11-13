import Foundation

public enum IdentityRules {
    // Specific contact and document formats only. Broad proper-noun recognition
    // belongs to the contextual on-device detector so brands remain intact.
    private static let patterns: [(String, IdentityKind, Int)] = [
        (#"(?<![\p{L}\p{N}])[\p{L}\p{N}._%+-]+@[\p{L}\p{N}.-]+\.[\p{L}]{2,}(?![\p{L}\p{N}])"#, .contact, 0),
        (#"(?<!\d)(?:\+7|8)[\s()\-]*\d{3}[\s()\-]*\d{3}[\s()\-]*\d{2}[\s()\-]*\d{2}(?!\d)"#, .contact, 0),
        (#"(?i)(?:паспорт|passport)\s*(?:№|no\.?|number)?\s*\d{4}\s*\d{6}(?!\d)"#, .document, 0),
        (#"(?i:доктор|врач|doctor|dr\.)\s+([А-ЯЁ][а-яё]+(?:\s+[А-ЯЁ][а-яё]+)?)"#, .doctor, 1),
        (#"(?i:пациент[а-яё]*|patient)\s+([А-ЯЁ][а-яё]+(?:\s+[А-ЯЁ][а-яё]+)?)"#, .patient, 1)
    ]

    public static func detect(in text: String) throws -> [IdentifyingSpan] {
        let full = NSRange(location: 0, length: (text as NSString).length)
        return try patterns.flatMap { pattern, kind, capture in
            let regex = try NSRegularExpression(pattern: pattern)
            return regex.matches(in: text, range: full).map {
                let range = $0.range(at: capture)
                return IdentifyingSpan(startUTF16: range.location,
                                       endUTF16: NSMaxRange(range), kind: kind)
            }
        }
    }
}
