import XCTest
import MeetingDataKit
import PrivacyPolicyKit
import TranscriptionKit
final class ContractsTests: XCTestCase {
    func testDefaultPolicyIsIndependentAndPrivate() throws {
        var meeting = Meeting(title: "Synthetic test", language: "en-US")
        meeting.accessPolicy.reports.visibility = .organization
        XCTAssertEqual(meeting.accessPolicy.audio.visibility, .private)
        XCTAssertEqual(meeting.accessPolicy.transcript.visibility, .private)
        XCTAssertFalse(AccessPolicyEvaluator.canRead(meeting.accessPolicy.audio, owner: "a", subject: "b", sameOrganization: true))
        XCTAssertTrue(AccessPolicyEvaluator.canRead(meeting.accessPolicy.reports, owner: "a", subject: "b", sameOrganization: true))
        XCTAssertFalse(AccessPolicyEvaluator.canRead(meeting.accessPolicy.reports, owner: "a", subject: nil, sameOrganization: true))
    }
    func testRoundTripAndVersionRejection() throws {
        var meeting = Meeting(title: "Synthetic", language: "en-US")
        meeting.extensions = ["org.example.test": .object(["retained": .bool(true)])]
        let data = try MeetingCodec.encode(meeting)
        XCTAssertEqual(try MeetingCodec.decode(data), meeting)
        let future = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "0.1", with: "1.0")
        XCTAssertThrowsError(try MeetingCodec.decode(Data(future.utf8)))
    }
    func testRejectsUnboundedDurationAndNonCAFFilename() throws {
        var m = Meeting(title: "Synthetic", language: "en-US")
        m.recording.chunks = [.init(filename: "audio.caf", duration: 1e308, sha256: String(repeating: "a", count: 64))]
        XCTAssertThrowsError(try MeetingCodec.encode(m))
        m.recording.chunks = [.init(filename: "audio.txt", duration: 1, sha256: String(repeating: "a", count: 64))]
        XCTAssertThrowsError(try MeetingCodec.encode(m))
    }
    func testExportsFixtureForIndependentSchemaValidation() throws {
        if let path = ProcessInfo.processInfo.environment["OPMS_FIXTURE_PATH"] {
            var m = Meeting(title: "Synthetic native fixture", language: "en-US")
            m.recording.chunks = [.init(filename: "audio.caf", duration: 2, sha256: String(repeating: "a", count: 64))]
            m.transcript = Transcript(meetingID: m.id, language: "en-US", segments: [.init(start: 0, end: 1, text: "Synthetic")])
            try MeetingCodec.encode(m).write(to: URL(fileURLWithPath: path))
        }
    }
    func testFractionalTimestampRoundTrip() throws {
        var m = Meeting(title: "Synthetic", language: "en-US")
        m.createdAt = Date(timeIntervalSince1970: 1794009600.123456)
        let restored = try MeetingCodec.decode(MeetingCodec.encode(m))
        XCTAssertEqual(restored.createdAt.timeIntervalSince1970, m.createdAt.timeIntervalSince1970, accuracy: 0.000001)
    }
    func testInvalidSegmentRejected() throws {
        var meeting = Meeting(title: "Test", language: "en-US")
        meeting.transcript = Transcript(meetingID: meeting.id, language: "en-US", segments: [.init(start: 3, end: 2, text: "invalid")])
        XCTAssertThrowsError(try MeetingCodec.encode(meeting))
    }
    func testChunkOffsetsAndBoundaries() throws {
        XCTAssertEqual(try ChunkPlan.ranges(duration: 91).map(\.start), [0, 45, 90])
        XCTAssertEqual(try ChunkPlan.ranges(duration: 91).map(\.duration), [45, 45, 1])
        XCTAssertThrowsError(try ChunkPlan.ranges(duration: .infinity))
        XCTAssertThrowsError(try ChunkPlan.ranges(duration: -1))
    }
    func testRepositoryRoundTripAndRecovery() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LocalMeetingRepository(root: root)
        var meeting = Meeting(title: "Test", language: "en-US")
        meeting.recording.state = .recording
        try store.save(meeting)
        XCTAssertEqual(try store.load(meeting.id), meeting)
        XCTAssertEqual(try store.recoverInterrupted().first?.recording.state, .interrupted)
        XCTAssertEqual(try store.list().meetings.count, 1)
        try Data("broken".utf8).write(to: root.appendingPathComponent("corrupt.json"))
        XCTAssertEqual(try store.list().unreadableFiles.count, 1)
        XCTAssertThrowsError(try store.audioURL(meeting.id, filename: "../escape.caf"))
        try store.delete(meeting.id)
        XCTAssertTrue(try store.list().meetings.isEmpty)
    }
}
