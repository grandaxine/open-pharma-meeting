import Foundation
import PrivacyPolicyKit

enum LocalModelStore {
    static let expectedSHA256 = "9465e63a22add5354d9bb4b99e90117043c7124007664907259bd16d043bb031"
    private static let filename = "Qwen3-0.6B-Q8_0.gguf"

    static var installedURL: URL? {
        guard let url = try? modelURL(), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    static func verifiedModelURL() throws -> URL {
        try Task.checkCancellation()
        let url = try modelURL()
        try ModelIntegrity.verify(url: url, expectedSHA256: expectedSHA256)
        try Task.checkCancellation()
        return url
    }

    static func importApprovedModel(from source: URL) throws {
        try Task.checkCancellation()
        let directory = try modelDirectory()
        let destination = directory.appendingPathComponent(filename)
        let staged = directory.appendingPathComponent(UUID().uuidString + ".partial")
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        defer { try? FileManager.default.removeItem(at: staged) }
        try FileManager.default.copyItem(at: source, to: staged)
        try Task.checkCancellation()
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: staged.path)
        try ModelIntegrity.verify(url: staged, expectedSHA256: expectedSHA256)
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

    private static func modelURL() throws -> URL { try modelDirectory().appendingPathComponent(filename) }

    private static func modelDirectory() throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory,
                                                   in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = support.appendingPathComponent("LocalModels", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        return directory
    }
}
