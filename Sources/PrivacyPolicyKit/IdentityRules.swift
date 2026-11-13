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
    private static let greeting = #"(?i:здравствуйте|добрый\s+день)\s*,?\s+([А-ЯЁ][а-яё]{2,})"#

    public static func detect(in text: String) throws -> [IdentifyingSpan] {
        let full = NSRange(location: 0, length: (text as NSString).length)
        var spans = try patterns.flatMap { pattern, kind, capture in
            let regex = try NSRegularExpression(pattern: pattern)
            return regex.matches(in: text, range: full).map {
                let range = $0.range(at: capture)
                return IdentifyingSpan(startUTF16: range.location,
                                       endUTF16: NSMaxRange(range), kind: kind)
            }
        }
        let source = text as NSString
        let regex = try NSRegularExpression(pattern: greeting)
        for match in regex.matches(in: text, range: full) {
            let name = source.substring(with: match.range(at: 1))
            var search = full
            while search.length > 0 {
                let found = source.range(of: name, options: [.caseInsensitive], range: search)
                guard found.location != NSNotFound else { break }
                if isWholeWord(found, in: source) && !isBrandContext(found.location, in: source) {
                    spans.append(IdentifyingSpan(startUTF16: found.location,
                                                 endUTF16: NSMaxRange(found), kind: .doctor))
                }
                let next = NSMaxRange(found)
                search = NSRange(location: next, length: source.length - next)
            }
        }
        return spans
    }

    private static func isWholeWord(_ range: NSRange, in text: NSString) -> Bool {
        func isWord(_ offset: Int) -> Bool {
            guard offset >= 0, offset < text.length,
                  let scalar = UnicodeScalar(Int(text.character(at: offset))) else { return false }
            return CharacterSet.alphanumerics.contains(scalar)
        }
        return !isWord(range.location - 1) && !isWord(NSMaxRange(range))
    }

    private static func isBrandContext(_ offset: Int, in text: NSString) -> Bool {
        let start = max(0, offset - 40)
        let prefix = text.substring(with: NSRange(location: start, length: offset - start))
        return prefix.range(of: #"(?i)(?:препарат[а-яё]*|бренд[а-яё]*|лекарств[а-яё]*|компан[а-яё]*|drug|brand|company)\s+$"#,
                            options: .regularExpression) != nil
    }
}
