#if os(iOS)
import AVFoundation
import Speech
import CryptoKit
import MeetingDataKit

@MainActor public final class AppleSpeechEngine: TranscriptionEngine {
    public init() {}
    public func supports(language: String) -> Bool {
        SFSpeechRecognizer(locale: Locale(identifier: language))?.supportsOnDeviceRecognition == true
    }
    public func transcribe(meeting: Meeting, repository: LocalMeetingRepository, progress: @escaping @Sendable (Double) -> Void) async throws -> Transcript {
        let authorized = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) } }
        guard authorized else { throw ContractError.invalid("Speech permission denied. Enable it in Settings.") }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: meeting.language)), recognizer.supportsOnDeviceRecognition else {
            throw ContractError.invalid("On-device speech is unavailable for this language. Recording remains local; choose a supported language/device configuration.")
        }
        guard recognizer.isAvailable else { throw ContractError.invalid("Speech recognizer unavailable") }
        guard !meeting.recording.chunks.isEmpty else { throw ContractError.invalid("No completed audio chunks") }
        var segments: [TranscriptSegment] = []; var offset = 0.0
        for (index, chunk) in meeting.recording.chunks.enumerated() {
            try Task.checkCancellation()
            let sourceURL = try repository.audioURL(meeting.id, filename: chunk.filename)
            let hash = SHA256.hash(data: try Data(contentsOf: sourceURL, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined()
            guard hash == chunk.sha256 else { throw ContractError.invalid("Audio integrity check failed") }
            let source = try AVAudioFile(forReading: sourceURL)
            let actualDuration = Double(source.length) / source.processingFormat.sampleRate
            guard abs(actualDuration - chunk.duration) < 0.1 else { throw ContractError.invalid("Audio duration mismatch") }
            for range in try ChunkPlan.ranges(duration: actualDuration) {
                try Task.checkCancellation()
                let temp = try repository.audioURL(meeting.id, filename: "speech-" + UUID().uuidString + ".caf")
                defer { try? FileManager.default.removeItem(at: temp) }
                try slice(source, range: range, destination: temp)
                let recognized = try await RecognitionOperation().run(recognizer: recognizer, url: temp)
                for segment in recognized {
                    segments.append(.init(start: offset + range.start + segment.start, end: offset + range.start + segment.end, text: segment.text))
                }
            }
            offset += actualDuration
            progress(Double(index + 1) / Double(meeting.recording.chunks.count))
        }
        guard !segments.isEmpty else { throw ContractError.invalid("No speech recognized; original audio preserved") }
        return Transcript(meetingID: meeting.id, language: meeting.language, segments: segments)
    }
    private func slice(_ source: AVAudioFile, range: ChunkRange, destination: URL) throws {
        let format = source.processingFormat
        source.framePosition = AVAudioFramePosition(range.start * format.sampleRate)
        let frames = AVAudioFrameCount(min(range.duration * format.sampleRate, Double(source.length - source.framePosition)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { throw ContractError.invalid("Audio buffer unavailable") }
        try source.read(into: buffer, frameCount: frames)
        let output = try AVAudioFile(forWriting: destination, settings: format.settings)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destination.path)
        try output.write(from: buffer)
    }
}

/// Main-actor completion gate serializes timeout, cancellation and Speech callbacks.
@MainActor private final class RecognitionOperation {
    private var continuation: CheckedContinuation<[TranscriptSegment], Error>?
    private var task: SFSpeechRecognitionTask?
    private var timeout: Task<Void, Never>?
    func run(recognizer: SFSpeechRecognizer, url: URL) async throws -> [TranscriptSegment] {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { c in
                continuation = c
                let request = SFSpeechURLRecognitionRequest(url: url)
                request.requiresOnDeviceRecognition = true
                request.shouldReportPartialResults = false
                task = recognizer.recognitionTask(with: request) { result, error in
                    let values = result?.isFinal == true ? result?.bestTranscription.segments.map {
                        TranscriptSegment(start: $0.timestamp, end: $0.timestamp + $0.duration, text: $0.substring)
                    } : nil
                    Task { @MainActor in
                        if let values { self.finish(.success(values)) }
                        else if let error { self.finish(.failure(error)) }
                    }
                }
                timeout = Task { @MainActor in
                    do { try await Task.sleep(nanoseconds: 90_000_000_000) } catch { return }
                    self.finish(.failure(ContractError.invalid("On-device speech timed out; audio preserved")))
                }
            }
        } onCancel: { Task { @MainActor in self.finish(.failure(CancellationError())) } }
    }
    private func finish(_ result: Result<[TranscriptSegment], Error>) {
        guard let c = continuation else { return }
        continuation = nil; timeout?.cancel(); timeout = nil; task?.cancel(); task = nil
        c.resume(with: result)
    }
}
#endif
