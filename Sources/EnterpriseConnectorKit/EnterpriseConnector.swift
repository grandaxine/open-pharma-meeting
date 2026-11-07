import Foundation
import MeetingDataKit
public struct ConnectorCapabilities: Codable, Sendable {
    public var schemaVersion: String
    public var protocolVersions: [String]
    public var issuer: URL
    public var apiBaseURL: URL
    public var scopes: [String]
}
public enum JobState: String, Codable, Sendable { case queued, running, succeeded, failed, cancelled }
public struct ProcessingJob: Codable, Sendable {
    public var schemaVersion: String
    public var id: UUID
    public var meetingID: UUID
    public var state: JobState
}
public struct ProcessingResult: Codable, Sendable {
    public var schemaVersion: String
    public var jobID: UUID
    public var reports: [ReportArtifact]
}
/// A company-owned adapter supplies OIDC/PKCE and server-enforced authorization.
/// No production network implementation is enabled in milestone 1.
public protocol EnterpriseConnector {
    func discover(at approvedCompanyURL: URL) async throws -> ConnectorCapabilities
    func authenticate() async throws
    func submit(_ transcript: Transcript, idempotencyKey: UUID) async throws
    func createJob(meetingID: UUID, idempotencyKey: UUID) async throws -> ProcessingJob
    func job(_ id: UUID) async throws -> ProcessingJob
    func result(_ id: UUID) async throws -> ProcessingResult
    func reports(meetingID: UUID) async throws -> [ReportArtifact]
    func sync(_ report: ReportArtifact, revision: Int, idempotencyKey: UUID) async throws
    func updatePolicy(meetingID: UUID, policy: AccessPolicy, revision: Int, idempotencyKey: UUID) async throws -> AccessPolicy
}
public protocol SecureStorage {
    func put(_ value: Data, key: String) throws
    func get(key: String) throws -> Data?
    func delete(key: String) throws
}
