import Foundation

public enum IdentityRules {
    // Specific contact and document formats only. Broad proper-noun recognition
    // belongs to the contextual on-device detector so brands remain intact.
    private static let patterns: [(String, IdentityKind)] = [
        (#"(?<![\p{L}\p{N}])[\p{L}\p{N}._%+-]+@[\p{L}\p{N}.-]+\.[\p{L}]{2,}(?![\p{L}\p{N}])"#, .contact),
        (#"(?<!\d)(?:\+7|8)[\s()\-]*\d{3}[\s()\-]*\d{3}[\s()\-]*\d{2}[\s()\-]*\d{2}(?!\d)"#, .contact),
        (#"(?i)(?:паспорт|passport)\s*(?:№|no\.?|number)?\s*\d{4}\s*\d{6}(?!\d)"#, .document)
    ]

    public static func detect(in text: String) throws -> [IdentifyingSpan] {
        let full = NSRange(location: 0, length: (text as NSString).length)
        return try patterns.flatMap { pattern, kind in
            let regex = try NSRegularExpression(pattern: pattern)
            return regex.matches(in: text, range: full).map {
                IdentifyingSpan(startUTF16: $0.range.location,
                                endUTF16: NSMaxRange($0.range), kind: kind)
            }
        }
    }
}
