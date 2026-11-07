import Foundation
import MeetingDataKit
@MainActor public protocol AudioRecorder: AnyObject {
    var meeting: Meeting? { get }
    func start(_ meeting: Meeting, repository: LocalMeetingRepository) async throws
    func pause() throws
    func resume() throws
    func stop() throws -> Meeting
}
public enum CaptureLimits {
    public static let chunkSeconds: TimeInterval = 60
    public static let reserveBytes: Int64 = 250 * 1024 * 1024
    public static func canRecord(availableBytes: Int64) -> Bool { availableBytes >= reserveBytes }
}
