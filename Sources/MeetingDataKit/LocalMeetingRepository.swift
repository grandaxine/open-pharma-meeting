import Foundation
public struct RepositoryListing { public var meetings: [Meeting]; public var unreadableFiles: [String] }
public protocol MeetingRepository {
    func save(_ meeting: Meeting) throws
    func load(_ id: UUID) throws -> Meeting
    func list() throws -> RepositoryListing
    func delete(_ id: UUID) throws
}
public struct LocalMeetingRepository: MeetingRepository {
    public let root: URL
    public init(root: URL? = nil) throws {
        self.root = try root ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("OpenPharmaMeeting", isDirectory: true)
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
        var url = self.root; var values = URLResourceValues(); values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: self.root.path)
        #endif
    }
    public func audioURL(_ id: UUID, filename: String) throws -> URL {
        try MeetingCodec.validateFilename(filename)
        let folder = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(filename)
        for path in [folder, url] where FileManager.default.fileExists(atPath: path.path) {
            if try path.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true { throw ContractError.invalid("Symbolic links forbidden") }
        }
        return url
    }
    public func save(_ meeting: Meeting) throws {
        let data = try MeetingCodec.encode(meeting)
        #if os(iOS)
        let active = [.recording, .paused].contains(meeting.recording.state)
        try data.write(to: metadataURL(meeting.id), options: [.atomic, active ? .completeFileProtectionUnlessOpen : .completeFileProtection])
        #else
        try data.write(to: metadataURL(meeting.id), options: .atomic)
        #endif
    }
    public func load(_ id: UUID) throws -> Meeting {
        let url = metadataURL(id)
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= MeetingCodec.maximumBytes else { throw ContractError.invalid("Payload too large") }
        let m = try MeetingCodec.decode(Data(contentsOf: url))
        guard m.id == id else { throw ContractError.invalid("Identifier mismatch") }
        return m
    }
    public func list() throws -> RepositoryListing {
        var meetings: [Meeting] = []; var bad: [String] = []
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) where url.pathExtension == "json" {
            do {
                guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { throw ContractError.invalid("Filename") }
                meetings.append(try load(id))
            } catch { bad.append(url.lastPathComponent) }
        }
        return .init(meetings: meetings.sorted { $0.createdAt > $1.createdAt }, unreadableFiles: bad)
    }
    public func recoverInterrupted() throws -> [Meeting] {
        var recovered: [Meeting] = []
        for var m in try list().meetings where [.recording, .paused].contains(m.recording.state) {
            m.recording.state = .interrupted; try save(m); recovered.append(m)
        }
        return recovered
    }
    public func delete(_ id: UUID) throws {
        // Delete metadata last; partial filesystem failure remains discoverable.
        let folder = root.appendingPathComponent(id.uuidString)
        if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
        try FileManager.default.removeItem(at: metadataURL(id))
    }
    public func importMeeting(_ data: Data) throws -> Meeting {
        let m = try MeetingCodec.decode(data)
        guard !FileManager.default.fileExists(atPath: metadataURL(m.id).path) else { throw ContractError.invalid("Meeting already exists") }
        // Metadata imports never imply that referenced audio was imported.
        try save(m); return m
    }
    private func metadataURL(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString + ".json") }
}
