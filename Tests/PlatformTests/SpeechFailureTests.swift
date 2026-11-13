import Foundation
import XCTest
import TranscriptionKit

final class SpeechFailureTests: XCTestCase {
    func testDisabledSiriOrDictationIsRecognized() {
        let error = NSError(domain: "kLSRErrorDomain", code: 201)
        XCTAssertEqual(SpeechFailure.classify(error), .siriOrDictationDisabled)
    }

    func testMissingSpeechAssetsAreRecognized() {
        let error = NSError(domain: "kLSRErrorDomain", code: 102)
        XCTAssertEqual(SpeechFailure.classify(error), .assetsMissing)
    }

    func testUnrelatedErrorIsNotMisclassified() {
        let error = NSError(domain: NSCocoaErrorDomain, code: 201)
        XCTAssertNil(SpeechFailure.classify(error))
    }
}
