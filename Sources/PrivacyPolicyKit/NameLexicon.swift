import Foundation

/// A small local seed list for Russian speech forms. Context still decides
/// whether a matched word identifies a person; this is not a name blacklist.
public enum NameLexicon {
    public static let givenNames = [
        "Александр", "Алексей", "Андрей", "Анна", "Василий", "Владимир",
        "Дмитрий", "Евгений", "Елена", "Иван", "Ирина", "Мария", "Марья",
        "Михаил", "Наталья", "Николай", "Олег", "Ольга", "Павел",
        "Петр", "Пётр", "Сергей", "Татьяна", "Юрий"
    ]

    // Curated examples, including ASR-style concatenation and colloquial
    // patronymics. They are provisional speech aliases, not legal names.
    public static let spokenGroups: [[String]] = [
        ["Мария Ивановна", "Марья Ивановна", "Марь Иванна", "Мариванна", "Марьиванна", "Марьванна", "Мариванн", "Марьиванн", "Марьванн"],
        ["Евгений Петрович", "Евгенийпетрович", "Евгений Петрыч", "Евгенийпетрыч"],
        ["Василий Олегович", "Василийолегович", "Василий Олегыч", "Василийолегыч"]
    ]

    public static let patronymicForms: [String: [String]] = [
        "Александрович": ["Александрыч", "Саныч"],
        "Андреевич": ["Андреич"],
        "Дмитриевич": ["Дмитрич"],
        "Иванович": ["Иваныч"],
        "Ивановна": ["Иванна"],
        "Михайлович": ["Михалыч"],
        "Николаевич": ["Николаич"],
        "Олегович": ["Олегыч"],
        "Павлович": ["Палыч"],
        "Петрович": ["Петрыч"],
        "Сергеевич": ["Сергеич"],
        "Степанович": ["Степаныч"]
    ]

    private static let patronymicSuffix = #"(?i)(?:ович|евич|овна|евна|ична|ыч|ич)$"#
    private static let namePattern: NSRegularExpression? = {
        let names = givenNames.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        return try? NSRegularExpression(
            pattern: #"(?<![\p{L}\p{N}])(?:"# + names + #")(?:\s*[А-ЯЁа-яё]{2,}(?:ович|евич|овна|евна|ична|ыч|ич))?(?![\p{L}\p{N}])"#,
            options: [.caseInsensitive])
    }()

    public static func mentionedForms(in text: String) -> [String] {
        let source = text as NSString
        let full = NSRange(location: 0, length: source.length)
        var matches = namePattern?.matches(in: text, range: full).map {
            source.substring(with: $0.range)
        } ?? []
        for form in spokenGroups.flatMap({ $0 }) {
            let pattern = #"(?<![\p{L}\p{N}])"# + NSRegularExpression.escapedPattern(for: form) + #"(?![\p{L}\p{N}])"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            matches += regex.matches(in: text, range: full).map { source.substring(with: $0.range) }
        }
        for form in patronymicForms.values.flatMap({ $0 }).sorted() {
            let pattern = #"(?<![\p{L}\p{N}])"# + NSRegularExpression.escapedPattern(for: form) + #"(?![\p{L}\p{N}])"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            matches += regex.matches(in: text, range: full).map { source.substring(with: $0.range) }
        }
        var seen = Set<String>()
        return matches.filter { seen.insert($0.lowercased()).inserted }
    }

    public static func addressVariants(for address: String) -> [String] {
        let folded = address.lowercased()
        if let group = spokenGroups.first(where: { $0.contains { $0.lowercased() == folded } }) {
            return group + [String(group[0].split(separator: " ")[0])]
        }
        let parts = address.split(separator: " ").map(String.init)
        if parts.count == 2, isPatronymic(parts[1]) {
            return patronymicVariants(for: parts[1]).flatMap { [parts[0] + " " + $0, parts[0] + $0] } + [parts[0]]
        }
        if parts.count == 1 {
            for name in givenNames where folded.hasPrefix(name.lowercased()) && folded.count > name.count {
                let rest = String(address.dropFirst(name.count))
                if isPatronymic(rest) {
                    return patronymicVariants(for: rest).flatMap { [name + " " + $0, name + $0] } + [name]
                }
            }
        }
        return [address]
    }

    public static func canonicalKey(for form: String) -> String? {
        let folded = form.lowercased()
        if let known = spokenGroups.first(where: { $0.contains { $0.lowercased() == folded } })?.first {
            return known.lowercased()
        }
        let parts = form.split(separator: " ").map(String.init)
        if parts.count == 2, isPatronymic(parts[1]) {
            return parts[0].lowercased() + canonicalPatronymic(parts[1]).lowercased()
        }
        if parts.count == 1 {
            for name in givenNames where folded.hasPrefix(name.lowercased()) && folded.count > name.count {
                let rest = String(form.dropFirst(name.count))
                if isPatronymic(rest) { return name.lowercased() + canonicalPatronymic(rest).lowercased() }
            }
        }
        return nil
    }

    private static func canonicalPatronymic(_ word: String) -> String {
        patronymicForms.first(where: {
            $0.key.caseInsensitiveCompare(word) == .orderedSame ||
            $0.value.contains { $0.caseInsensitiveCompare(word) == .orderedSame }
        })?.key ?? word
    }

    private static func patronymicVariants(for word: String) -> [String] {
        let canonical = canonicalPatronymic(word)
        return [canonical] + (patronymicForms[canonical] ?? [])
    }

    private static func isPatronymic(_ word: String) -> Bool {
        word.range(of: patronymicSuffix, options: .regularExpression) != nil
    }
}
