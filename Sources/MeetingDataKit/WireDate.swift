import Foundation
/// RFC3339 codec with explicit fractional handling compatible with iPadOS 16 Foundation.
/// Emits UTC with microsecond precision; accepts up to nanosecond text precision.
public enum WireDate {
    public static func string(_ date: Date) throws -> String {
        let time = date.timeIntervalSince1970
        guard time.isFinite, time >= 0, time < 253402300799 else { throw ContractError.invalid("Date outside supported range") }
        var whole = floor(time)
        var micros = Int(((time - whole) * 1_000_000).rounded())
        if micros == 1_000_000 { whole += 1; micros = 0 }
        let formatter = ISO8601DateFormatter()
        let base = formatter.string(from: Date(timeIntervalSince1970: whole))
        return String(base.dropLast()) + String(format: ".%06dZ", micros)
    }
    public static func parse(_ text: String) throws -> Date {
        let expression = try NSRegularExpression(pattern: #"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.([0-9]{1,9}))?(Z|[+-]\d{2}:\d{2})$"#)
        let ns = text as NSString
        guard let match = expression.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { throw ContractError.invalid("Invalid RFC3339 date") }
        let base = ns.substring(with: match.range(at: 1)) + ns.substring(with: match.range(at: 3))
        guard let date = ISO8601DateFormatter().date(from: base) else { throw ContractError.invalid("Invalid RFC3339 date") }
        let fraction = match.range(at: 2).location == NSNotFound ? 0 : Double("0." + ns.substring(with: match.range(at: 2))) ?? 0
        return date.addingTimeInterval(fraction)
    }
}
