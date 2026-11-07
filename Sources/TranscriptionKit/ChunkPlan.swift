import Foundation
import MeetingDataKit
public struct ChunkRange: Equatable { public var start: Double; public var duration: Double }
public enum ChunkPlan {
    public static func ranges(duration: Double) throws -> [ChunkRange] {
        guard duration.isFinite, duration >= 0, duration <= 86400 else { throw ContractError.invalid("Invalid media duration") }
        return stride(from: 0.0, to: duration, by: 45).map { .init(start: $0, duration: min(45, duration - $0)) }
    }
}
@MainActor public protocol TranscriptionEngine {
    func supports(language: String) -> Bool
    func transcribe(meeting: Meeting, repository: LocalMeetingRepository, progress: @escaping @Sendable (Double) -> Void) async throws -> Transcript
}
