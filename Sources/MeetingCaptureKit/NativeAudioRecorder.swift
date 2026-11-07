#if os(iOS)
import AVFoundation
import Combine
import CryptoKit
import Foundation
import MeetingDataKit

@MainActor public final class NativeAudioRecorder: NSObject, AudioRecorder, ObservableObject, AVAudioRecorderDelegate {
    @Published public private(set) var meeting: Meeting?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var elapsed: Double = 0
    private var repository: LocalMeetingRepository?
    private var recorder: AVAudioRecorder?
    private var ticker: Timer?
    private var interruption: NSObjectProtocol?
    public override init() {
        super.init()
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor in self?.fail("Audio session interrupted. Review and resume explicitly.") }
        }
    }
    deinit { ticker?.invalidate(); if let interruption { NotificationCenter.default.removeObserver(interruption) } }
    public func start(_ input: Meeting, repository: LocalMeetingRepository) async throws {
        guard meeting == nil, input.consentAcknowledgedAt != nil else { throw ContractError.invalid("Consent required or capture active") }
        let allowed = await withCheckedContinuation { c in AVAudioSession.sharedInstance().requestRecordPermission { c.resume(returning: $0) } }
        guard allowed else { throw ContractError.invalid("Microphone permission denied. Open Settings to enable it.") }
        var m = input; m.recording.state = .recording
        self.repository = repository; self.meeting = m; errorMessage = nil
        do {
            try repository.save(m)
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try beginChunk()
            ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        } catch { fail("Recording could not start: \(error.localizedDescription)"); throw error }
    }
    public func pause() throws {
        guard meeting?.recording.state == .recording else { return }
        do { try finishChunk(); meeting?.recording.state = .paused; try persist() }
        catch { fail("Pause failed; recording interrupted."); throw error }
    }
    public func resume() throws {
        guard meeting?.recording.state == .paused else { return }
        do { meeting?.recording.state = .recording; try beginChunk() }
        catch { fail("Unable to resume recording."); throw error }
    }
    public func stop() throws -> Meeting {
        guard meeting != nil else { throw ContractError.invalid("No active recording") }
        do {
            try finishChunk(); meeting?.recording.state = .completed; try persist()
            let result = meeting!; cleanup(); return result
        } catch { fail("Could not finalize recording; recover from the meeting list."); throw error }
    }
    private func beginChunk() throws {
        guard var m = meeting, let repository else { throw ContractError.invalid("Missing repository") }
        guard m.recording.duration < 86400 - CaptureLimits.chunkSeconds else { throw ContractError.invalid("24-hour meeting limit reached") }
        let attrs = try FileManager.default.attributesOfFileSystem(forPath: repository.root.path)
        let free = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        guard CaptureLimits.canRecord(availableBytes: free) else { throw ContractError.invalid("Storage reserve reached") }
        let filename = UUID().uuidString + ".caf"
        m.recording.pendingFilename = filename; meeting = m; try persist()
        let url = try repository.audioURL(m.id, filename: filename)
        let audio = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000.0, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: url.path)
        audio.delegate = self
        guard audio.record() else { throw ContractError.invalid("Audio recording failed") }
        recorder = audio
    }
    private func finishChunk() throws {
        guard let audio = recorder else { return }
        audio.stop(); recorder = nil
        guard var m = meeting, let repository, let filename = m.recording.pendingFilename else { throw ContractError.invalid("Missing capture journal") }
        let url = try repository.audioURL(m.id, filename: filename)
        let file = try AVAudioFile(forReading: url)
        let duration = Double(file.length) / file.processingFormat.sampleRate
        guard duration > 0 else { throw ContractError.invalid("Empty audio chunk") }
        let digest = SHA256.hash(data: try Data(contentsOf: url, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined()
        m.recording.chunks.append(.init(filename: filename, duration: duration, sha256: digest))
        m.recording.pendingFilename = nil; meeting = m; try persist()
        elapsed = m.recording.duration
    }
    private func persist() throws { if let meeting, let repository { try repository.save(meeting) } }
    private func tick() {
        guard meeting?.recording.state == .recording else { return }
        elapsed = (meeting?.recording.duration ?? 0) + (recorder?.currentTime ?? 0)
        if (recorder?.currentTime ?? 0) >= CaptureLimits.chunkSeconds {
            do { try finishChunk(); try beginChunk() } catch { fail("Recording stopped: storage or audio failure. Completed chunks retained.") }
        }
    }
    private func fail(_ message: String) {
        errorMessage = message
        do { try finishChunk() } catch { /* Pending filename remains available for explicit recovery. */ }
        meeting?.recording.state = .interrupted
        do { try persist() } catch { errorMessage = message + " Journal could not be saved; relaunch to recover." }
        cleanup()
    }
    private func cleanup() {
        ticker?.invalidate(); ticker = nil; recorder?.stop(); recorder = nil; meeting = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    nonisolated public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in self.fail("Audio encoding failed; review recovered recording.") }
    }
    nonisolated public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag { Task { @MainActor in self.fail("Audio recording ended unexpectedly.") } }
    }
}

public enum AudioIntegrity {
    /// Explicit recovery only: decode/hash a pending CAF without claiming lost samples are recoverable.
    public static func recover(_ meeting: Meeting, repository: LocalMeetingRepository) throws -> Meeting {
        var m = meeting
        guard m.recording.state == .interrupted, let pending = m.recording.pendingFilename else { return m }
        let url = try repository.audioURL(m.id, filename: pending)
        let file = try AVAudioFile(forReading: url)
        let duration = Double(file.length) / file.processingFormat.sampleRate
        guard duration > 0 else { throw ContractError.invalid("Pending audio is not recoverable") }
        let hash = SHA256.hash(data: try Data(contentsOf: url, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined()
        m.recording.chunks.append(.init(filename: pending, duration: duration, sha256: hash))
        m.recording.pendingFilename = nil; try repository.save(m); return m
    }
    public static func verify(_ chunk: AudioChunk, url: URL) throws {
        let hash = SHA256.hash(data: try Data(contentsOf: url, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined()
        guard hash == chunk.sha256 else { throw ContractError.invalid("Audio integrity verification failed") }
    }
}
#endif
