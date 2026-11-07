import Foundation
import MeetingDataKit
/// Deterministic in-memory company-service simulator for tests, never a security boundary.
/// No HTTP, credentials, model provider, persistence or tenant authorization is provided.
public actor MockEnterpriseConnector: EnterpriseConnector {
    private var authenticated = false
    private var transcripts: [UUID: Transcript] = [:]
    private var jobs: [UUID: ProcessingJob] = [:]
    private var results: [UUID: ProcessingResult] = [:]
    private var policies: [UUID: AccessPolicy] = [:]
    private var artifacts: [UUID: ReportArtifact] = [:]
    private var keys: [UUID: String] = [:]
    private var policyResponses: [UUID: AccessPolicy] = [:]
    private var completedReportKeys = Set<UUID>()
    private var jobKeys: [UUID: UUID] = [:]
    public init() {}
    public func discover(at approvedCompanyURL: URL) async throws -> ConnectorCapabilities {
        guard approvedCompanyURL.scheme == "https" else { throw ContractError.invalid("HTTPS required") }
        return .init(schemaVersion: "0.1", protocolVersions: ["0.1"], issuer: approvedCompanyURL, apiBaseURL: approvedCompanyURL, scopes: ["mock"])
    }
    public func authenticate() async throws { authenticated = true }
    private func requireAuth() throws { guard authenticated else { throw ContractError.invalid("Mock authentication required") } }
    private func check(_ key: UUID, operation: String, body: Data) throws {
        try requireAuth()
        let fingerprint = operation + ":" + body.base64EncodedString()
        if let prior = keys[key], prior != fingerprint { throw ContractError.invalid("Idempotency conflict") }
        keys[key] = fingerprint
    }
    public func submit(_ transcript: Transcript, idempotencyKey: UUID) async throws {
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        try check(idempotencyKey, operation: "transcript", body: e.encode(transcript))
        transcripts[transcript.meetingID] = transcript
    }
    public func createJob(meetingID: UUID, idempotencyKey: UUID) async throws -> ProcessingJob {
        try check(idempotencyKey, operation: "job", body: Data(meetingID.uuidString.utf8))
        if let id = jobKeys[idempotencyKey], let job = jobs[id] { return job }
        guard transcripts[meetingID] != nil else { throw ContractError.invalid("Transcript missing") }
        let job = ProcessingJob(schemaVersion: "0.1", id: UUID(), meetingID: meetingID, state: .queued)
        jobs[job.id] = job; jobKeys[idempotencyKey] = job.id; return job
    }
    public func job(_ id: UUID) async throws -> ProcessingJob {
        try requireAuth(); guard var job = jobs[id] else { throw ContractError.invalid("Job not found") }
        if job.state == .queued { job.state = .running }
        else if job.state == .running { job.state = .succeeded; complete(job) }
        jobs[id] = job; return job
    }
    private func complete(_ job: ProcessingJob) {
        guard results[job.id] == nil else { return }
        let report = ReportArtifact(meetingID: job.meetingID, type: "org.example.mock-summary", content: ["summary": .string("Synthetic mock result; no AI was called."), "decisions": .array([]), "actionItems": .array([])])
        results[job.id] = .init(schemaVersion: "0.1", jobID: job.id, reports: [report]); artifacts[report.id] = report
    }
    public func result(_ id: UUID) async throws -> ProcessingResult {
        try requireAuth(); guard var job = jobs[id] else { throw ContractError.invalid("Job not found") }
        job.state = .succeeded; jobs[id] = job; complete(job)
        return results[id]!
    }
    public func reports(meetingID: UUID) async throws -> [ReportArtifact] {
        try requireAuth(); return artifacts.values.filter { $0.meetingID == meetingID }.sorted { $0.id.uuidString < $1.id.uuidString }
    }
    public func sync(_ report: ReportArtifact, revision: Int, idempotencyKey: UUID) async throws {
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        try check(idempotencyKey, operation: "report:\(revision)", body: e.encode(report))
        guard !completedReportKeys.contains(idempotencyKey) else { return }
        artifacts[report.id] = report; completedReportKeys.insert(idempotencyKey)
    }
    public func updatePolicy(meetingID: UUID, policy: AccessPolicy, revision: Int, idempotencyKey: UUID) async throws -> AccessPolicy {
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        try check(idempotencyKey, operation: "policy:\(meetingID):\(revision)", body: e.encode(policy))
        if let original = policyResponses[idempotencyKey] { return original }
        let current = policies[meetingID] ?? AccessPolicy()
        guard current.revision == revision else { throw ContractError.invalid("Revision conflict") }
        var updated = policy; updated.revision = revision + 1; policies[meetingID] = updated; policyResponses[idempotencyKey] = updated; return updated
    }
}
