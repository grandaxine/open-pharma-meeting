import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else { self = .array(try c.decode([JSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        }
    }
}
public enum Visibility: String, Codable, Sendable { case `private` = "Private", restricted = "Restricted", organization = "Organization" }
public struct ResourceAccess: Codable, Equatable, Sendable {
    public var visibility: Visibility = .private
    public var employeeIDs: [String] = []
    public init() {}
}
public struct AccessPolicy: Codable, Equatable, Sendable {
    public var schemaVersion = "0.1"
    public var revision = 0
    public var audio = ResourceAccess()
    public var transcript = ResourceAccess()
    public var reports = ResourceAccess()
    public init() {}
}
public struct TranscriptSegment: Codable, Equatable, Identifiable, Sendable {
    public var id = UUID()
    public var start: Double
    public var end: Double
    public var text: String
    public init(start: Double, end: Double, text: String) { self.start = start; self.end = end; self.text = text }
}
public struct Transcript: Codable, Equatable, Sendable {
    public var schemaVersion = "0.1"
    public var meetingID: UUID
    public var language: String
    public var segments: [TranscriptSegment]
    public init(meetingID: UUID, language: String, segments: [TranscriptSegment]) {
        self.meetingID = meetingID; self.language = language; self.segments = segments
    }
    public var text: String { segments.map(\.text).joined(separator: " ") }
}
public struct AudioChunk: Codable, Equatable, Sendable {
    public var filename: String
    public var duration: Double
    public var sha256: String
    public init(filename: String, duration: Double, sha256: String) { self.filename = filename; self.duration = duration; self.sha256 = sha256 }
}
public enum RecordingState: String, Codable, Sendable { case ready, recording, paused, completed, interrupted }
public struct RecordingMetadata: Codable, Equatable, Sendable {
    public var schemaVersion = "0.1"
    public var state: RecordingState = .ready
    public var mediaType = "audio/x-caf"
    public var chunks: [AudioChunk] = []
    public var pendingFilename: String?
    public var duration: Double { chunks.reduce(0) { $0 + $1.duration } }
    public init() {}
}
public struct ReportArtifact: Codable, Equatable, Identifiable, Sendable {
    public var schemaVersion = "0.1"
    public var id: UUID
    public var meetingID: UUID
    public var type: String
    public var content: [String: JSONValue]
    public var requiresHumanReview: Bool
    public init(meetingID: UUID, type: String, content: [String: JSONValue], requiresHumanReview: Bool = true) {
        self.id = UUID(); self.meetingID = meetingID; self.type = type; self.content = content; self.requiresHumanReview = requiresHumanReview
    }
}
public struct Meeting: Codable, Equatable, Identifiable, Sendable {
    public var schemaVersion = "0.1"
    public var id = UUID()
    public var createdAt = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
    public var title: String
    public var language: String
    public var consentAcknowledgedAt: Date?
    public var recording = RecordingMetadata()
    public var transcript: Transcript?
    public var accessPolicy = AccessPolicy()
    public var reports: [ReportArtifact] = []
    public var extensions: [String: JSONValue] = [:]
    public init(title: String, language: String) { self.title = title; self.language = language }
}
public enum ContractError: Error { case invalid(String) }
public enum MeetingCodec {
    public static let maximumBytes = 100 * 1024 * 1024
    public static func encode(_ meeting: Meeting) throws -> Data {
        try validate(meeting)
        let e = JSONEncoder(); e.dateEncodingStrategy = .custom { date, encoder in var c = encoder.singleValueContainer(); try c.encode(WireDate.string(date)) }; e.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try e.encode(meeting)
        guard data.count <= maximumBytes else { throw ContractError.invalid("Payload too large") }
        return data
    }
    public static func decode(_ data: Data) throws -> Meeting {
        guard data.count <= maximumBytes else { throw ContractError.invalid("Payload too large") }
        let d = JSONDecoder(); d.dateDecodingStrategy = .custom { decoder in let c = try decoder.singleValueContainer(); return try WireDate.parse(c.decode(String.self)) }
        let m = try d.decode(Meeting.self, from: data); try validate(m); return m
    }
    public static func validate(_ m: Meeting) throws {
        guard m.schemaVersion == "0.1", m.recording.schemaVersion == "0.1", m.accessPolicy.schemaVersion == "0.1",
              !m.title.isEmpty, !m.language.isEmpty, m.accessPolicy.revision >= 0 else { throw ContractError.invalid("Unsupported version or invalid meeting") }
        for filename in m.recording.chunks.map(\.filename) + [m.recording.pendingFilename].compactMap({ $0 }) { try validateFilename(filename) }
        for c in m.recording.chunks {
            guard c.duration.isFinite, c.duration > 0, c.duration <= 86400, c.sha256.count == 64, c.sha256.allSatisfy({ $0.isHexDigit }) else { throw ContractError.invalid("Invalid chunk") }
        }
        guard m.recording.duration.isFinite, m.recording.duration <= 86400 else { throw ContractError.invalid("Recording exceeds 24-hour limit") }
        if let t = m.transcript {
            guard t.schemaVersion == "0.1", t.meetingID == m.id else { throw ContractError.invalid("Invalid transcript reference") }
            var previous = 0.0
            for s in t.segments {
                guard s.start.isFinite, s.end.isFinite, s.start >= previous, s.end >= s.start else { throw ContractError.invalid("Invalid timestamps") }
                previous = s.start
            }
        }
        guard Set(m.recording.chunks.map(\.filename)).count == m.recording.chunks.count else { throw ContractError.invalid("Duplicate chunks") }
        for r in m.reports { guard r.schemaVersion == "0.1", r.meetingID == m.id else { throw ContractError.invalid("Invalid report reference") } }
        guard m.extensions.keys.allSatisfy({ $0.contains(".") }) else { throw ContractError.invalid("Extension namespace required") }
    }
    public static func validateFilename(_ name: String) throws {
        guard !name.isEmpty, name.count < 128, name.hasSuffix(".caf"), name.first != ".", name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "-_.".contains($0)) }) else { throw ContractError.invalid("Unsafe filename") }
    }
}
