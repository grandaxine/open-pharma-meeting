import Foundation

public enum EntityResponseError: Error {
    case malformed
    case unmatchedQuote
}

public enum EntityResponseParser {
    public static func parse(_ response: String, in source: String) throws -> [IdentifyingSpan] {
        guard let data = response.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(root.keys) == ["entities"],
              let entities = root["entities"] as? [[String: Any]],
              entities.count <= 100 else { throw EntityResponseError.malformed }
        let text = source as NSString
        var spans: [IdentifyingSpan] = []
        for entity in entities {
            guard Set(entity.keys) == ["quote", "kind"],
                  let quote = entity["quote"] as? String,
                  !quote.isEmpty, quote.utf16.count <= 160,
                  let value = entity["kind"] as? String,
                  let kind = IdentityKind(rawValue: value) else {
                throw EntityResponseError.malformed
            }
            if [.doctor, .patient, .person].contains(kind) &&
                (quote.split(whereSeparator: \.isWhitespace).count > 4 ||
                 quote.rangeOfCharacter(from: CharacterSet(charactersIn: ".!?;")) != nil) {
                throw EntityResponseError.malformed
            }
            var search = NSRange(location: 0, length: text.length)
            var matched = false
            while search.length > 0 {
                let found = text.range(of: quote, options: [], range: search)
                guard found.location != NSNotFound else { break }
                spans.append(IdentifyingSpan(startUTF16: found.location,
                                             endUTF16: NSMaxRange(found), kind: kind))
                matched = true
                let next = NSMaxRange(found)
                search = NSRange(location: next, length: text.length - next)
            }
            guard matched else { throw EntityResponseError.unmatchedQuote }
        }
        return try IdentitySpans.validated(spans, in: source)
    }
}
