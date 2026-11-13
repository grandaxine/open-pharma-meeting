import Foundation
import PrivacyPolicyKit

enum LocalModelStoreError: Error {
    case notInstalled
}

enum LocalModelStore {
    private static let activeKey = "activeLocalModelProfile"

    static var activeProfile: LocalModelProfile {
        if let saved = UserDefaults.standard.string(forKey: activeKey),
           let profile = LocalModelProfile(rawValue: saved), installedURL(for: profile) != nil {
            return profile
        }
        return installedProfiles.first ?? .qwen
    }

    static var installedProfiles: [LocalModelProfile] {
        LocalModelProfile.allCases.filter { installedURL(for: $0) != nil }
    }

    static func installedURL(for profile: LocalModelProfile) -> URL? {
        guard let url = try? modelURL(for: profile), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    static func select(_ profile: LocalModelProfile) throws {
        guard installedURL(for: profile) != nil else { throw LocalModelStoreError.notInstalled }
        UserDefaults.standard.set(profile.id, forKey: activeKey)
    }

    static func verifiedModelURL(for profile: LocalModelProfile) throws -> URL {
        try Task.checkCancellation()
        guard let url = installedURL(for: profile) else { throw LocalModelStoreError.notInstalled }
        try ModelIntegrity.verify(url: url, expectedSHA256: profile.expectedSHA256)
        try Task.checkCancellation()
        return url
    }

    static func importApprovedModel(from source: URL, as profile: LocalModelProfile) throws {
        try Task.checkCancellation()
        let directory = try modelDirectory()
        let destination = directory.appendingPathComponent(profile.filename)
        let staged = directory.appendingPathComponent(UUID().uuidString + ".partial")
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        defer { try? FileManager.default.removeItem(at: staged) }
        try FileManager.default.copyItem(at: source, to: staged)
        try Task.checkCancellation()
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: staged.path)
        try ModelIntegrity.verify(url: staged, expectedSHA256: profile.expectedSHA256)
        try Task.checkCancellation()
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: staged)
        } else {
            try FileManager.default.moveItem(at: staged, to: destination)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var protectedURL = destination
        try protectedURL.setResourceValues(values)
    }

    private static func modelURL(for profile: LocalModelProfile) throws -> URL {
        try modelDirectory().appendingPathComponent(profile.filename)
    }

    private static func modelDirectory() throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory,
                                                   in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = support.appendingPathComponent("LocalModels", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        return directory
    }
}
