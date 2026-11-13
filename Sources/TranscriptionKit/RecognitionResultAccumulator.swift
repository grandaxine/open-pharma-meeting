import MeetingDataKit

struct RecognitionResultAccumulator {
    private(set) var segments: [TranscriptSegment] = []

    mutating func appendFinal(_ newSegments: [TranscriptSegment]) {
        for segment in newSegments {
            let alreadyPresent = segments.contains {
                abs($0.start - segment.start) < 0.05 &&
                abs($0.end - segment.end) < 0.05 &&
                $0.text == segment.text
            }
            if !alreadyPresent { segments.append(segment) }
        }
        segments.sort { $0.start < $1.start }
    }
}
