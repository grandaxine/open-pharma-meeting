import MeetingDataKit
public protocol AccessPolicyManager {
    func canRead(_ resource: ResourceAccess, owner: String, subject: String?, sameOrganization: Bool) -> Bool
    func update(meetingID: String, policy: AccessPolicy, expectedRevision: Int) async throws -> AccessPolicy
}
/// UI defense in depth only. Corporate backends must authorize every request independently.
public enum AccessPolicyEvaluator {
    public static func canRead(_ resource: ResourceAccess, owner: String, subject: String?, sameOrganization: Bool) -> Bool {
        guard let subject, !subject.isEmpty else { return false }
        if subject == owner { return true }
        switch resource.visibility {
        case .private: return false
        case .restricted: return sameOrganization && resource.employeeIDs.contains(subject)
        case .organization: return sameOrganization
        }
    }
}
