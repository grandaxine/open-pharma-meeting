import XCTest
import MeetingCaptureKit
final class CaptureTests: XCTestCase {
    func testReserveAndRotation() {
        XCTAssertFalse(CaptureLimits.canRecord(availableBytes: 250 * 1024 * 1024 - 1))
        XCTAssertTrue(CaptureLimits.canRecord(availableBytes: 250 * 1024 * 1024))
        XCTAssertEqual(CaptureLimits.chunkSeconds, 60)
    }
}
