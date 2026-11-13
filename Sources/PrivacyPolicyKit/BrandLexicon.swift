import Foundation

/// User-supplied brand names with provisional Russian speech spellings.
/// These are model hints, never an unconditional exemption from identity checks.
public enum BrandLexicon {
    public struct Entry: Sendable {
        public let canonical: String
        public let aliases: [String]
    }

    public static let entries: [Entry] = [
        .init(canonical: "Entresto", aliases: ["Entresto", "Энтресто"]),
        .init(canonical: "Cosentyx", aliases: ["Cosentyx", "Косентикс", "Козентикс", "Козэнтикс"]),
        .init(canonical: "Kisqali", aliases: ["Kisqali", "Кискали"]),
        .init(canonical: "Kesimpta", aliases: ["Kesimpta", "Кесимпта"]),
        .init(canonical: "Tafinlar + Mekinist", aliases: ["Tafinlar", "Mekinist", "Тафинлар", "Мекинист"]),
        .init(canonical: "Jakavi", aliases: ["Jakavi", "Джакави"]),
        .init(canonical: "Pluvicto", aliases: ["Pluvicto", "Плувикто", "Плювикто"]),
        .init(canonical: "Ilaris", aliases: ["Ilaris", "Иларис"]),
        .init(canonical: "Xolair", aliases: ["Xolair", "Ксолар"]),
        .init(canonical: "Promacta / Revolade", aliases: ["Promacta", "Revolade", "Промакта", "Револейд"]),
        .init(canonical: "Scemblix", aliases: ["Scemblix", "Скембликс"]),
        .init(canonical: "Zolgensma", aliases: ["Zolgensma", "Золгенсма"]),
        .init(canonical: "Sandostatin", aliases: ["Sandostatin", "Сандостатин"]),
        .init(canonical: "Leqvio", aliases: ["Leqvio", "Леквио"]),
        .init(canonical: "Tasigna", aliases: ["Tasigna", "Тасигна"]),
        .init(canonical: "Lutathera", aliases: ["Lutathera", "Лутатера"]),
        .init(canonical: "Exforge", aliases: ["Exforge", "Эксфорж"]),
        .init(canonical: "Lucentis", aliases: ["Lucentis", "Луцентис"]),
        .init(canonical: "Diovan", aliases: ["Diovan", "Диован"]),
        .init(canonical: "Fabhalta", aliases: ["Fabhalta", "Фабхалта"]),
        .init(canonical: "Rhapsido", aliases: ["Rhapsido", "Рапсидо"]),
        .init(canonical: "Vanrafia", aliases: ["Vanrafia", "Ванрафия", "Ванрафиа"]),
        .init(canonical: "Itvisma", aliases: ["Itvisma", "Итвисма"]),
        .init(canonical: "Aimovig", aliases: ["Aimovig", "Аймовиг"]),
        .init(canonical: "Gilenya", aliases: ["Gilenya", "Гиления"]),
        .init(canonical: "Glivec / Gleevec", aliases: ["Glivec", "Gleevec", "Гливек"]),
        .init(canonical: "Afinitor / Votubia", aliases: ["Afinitor", "Votubia", "Афинитор", "Вотубия"]),
        .init(canonical: "Beovu", aliases: ["Beovu", "Беову"])
    ]

    private static let patterns: [(String, NSRegularExpression)] = entries.flatMap { entry in
        entry.aliases.compactMap { alias in
            let escaped = NSRegularExpression.escapedPattern(for: alias)
            let pattern = #"(?<![\p{L}\p{N}])"# + escaped + #"(?![\p{L}\p{N}])"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
            return (alias, regex)
        }
    }

    public static func mentionedAliases(in text: String) -> [String] {
        let full = NSRange(location: 0, length: (text as NSString).length)
        var found: [String] = []
        var seen = Set<String>()
        for (alias, regex) in patterns where regex.firstMatch(in: text, range: full) != nil {
            let key = alias.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            if seen.insert(key).inserted { found.append(alias) }
        }
        return found
    }
}
