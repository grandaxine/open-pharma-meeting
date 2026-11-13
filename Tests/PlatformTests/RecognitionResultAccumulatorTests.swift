import XCTest
@testable import TranscriptionKit
import MeetingDataKit

final class RecognitionResultAccumulatorTests: XCTestCase {
    func testRetainsEarlierUtterancesAcrossFinalResults() {
        let opening = TranscriptSegment(start: 0.8, end: 1.2, text: "Здравствуйте")
        let response = TranscriptSegment(start: 10.8, end: 11.2, text: "Аудио")
        var accumulator = RecognitionResultAccumulator()

        accumulator.appendFinal([opening])
        accumulator.appendFinal([response])

        XCTAssertEqual(accumulator.segments, [opening, response])
    }

    func testCumulativeFinalResultDoesNotDuplicateEarlierWords() {
        let opening = TranscriptSegment(start: 0.8, end: 1.2, text: "Здравствуйте")
        let response = TranscriptSegment(start: 10.8, end: 11.2, text: "Аудио")
        var accumulator = RecognitionResultAccumulator()

        accumulator.appendFinal([opening])
        accumulator.appendFinal([opening, response])

        XCTAssertEqual(accumulator.segments, [opening, response])
    }
}
