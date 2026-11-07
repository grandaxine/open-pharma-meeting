import XCTest
import MeetingDataKit
import EnterpriseConnectorKit
final class ConnectorTests: XCTestCase {
    func testPolicyReplayReturnsOriginalWithoutOverwritingNewerRevision() async throws {
        let mock = MockEnterpriseConnector(); try await mock.authenticate()
        let meetingID = UUID(); let firstKey = UUID(); let policy = AccessPolicy()
        let first = try await mock.updatePolicy(meetingID: meetingID, policy: policy, revision: 0, idempotencyKey: firstKey)
        var next = first; next.reports.visibility = .organization
        _ = try await mock.updatePolicy(meetingID: meetingID, policy: next, revision: 1, idempotencyKey: UUID())
        let replay = try await mock.updatePolicy(meetingID: meetingID, policy: policy, revision: 0, idempotencyKey: firstKey)
        XCTAssertEqual(replay, first)
    }
    func testReportReplayDoesNotOverwriteNewerContent() async throws {
        let mock = MockEnterpriseConnector(); try await mock.authenticate()
        let id = UUID(); let key = UUID()
        let first = ReportArtifact(meetingID: id, type: "test", content: ["summary": .string("old")])
        try await mock.sync(first, revision: 0, idempotencyKey: key)
        var next = first; next.content = ["summary": .string("new")]
        try await mock.sync(next, revision: 1, idempotencyKey: UUID())
        try await mock.sync(first, revision: 0, idempotencyKey: key)
        let reports = try await mock.reports(meetingID: id)
        XCTAssertEqual(reports.first?.content, next.content)
    }
    func testMockRoundTripAndIdempotency() async throws {
        let mock = MockEnterpriseConnector()
        let id = UUID(); let key = UUID()
        try await mock.authenticate()
        try await mock.submit(Transcript(meetingID: id, language: "en-US", segments: []), idempotencyKey: UUID())
        let first = try await mock.createJob(meetingID: id, idempotencyKey: key)
        let replay = try await mock.createJob(meetingID: id, idempotencyKey: key)
        XCTAssertEqual(first.id, replay.id)
        let result = try await mock.result(first.id)
        XCTAssertEqual(result.reports.first?.meetingID, id)
        XCTAssertEqual(result.reports.first?.requiresHumanReview, true)
        do { _ = try await mock.createJob(meetingID: UUID(), idempotencyKey: key); XCTFail("Conflicting key must fail") } catch {}
    }
}
