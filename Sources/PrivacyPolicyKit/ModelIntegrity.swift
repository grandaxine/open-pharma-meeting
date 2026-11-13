import Foundation
import CryptoKit

public enum ModelIntegrityError: Error {
    case invalidExpectedHash
    case hashMismatch
}

public enum ModelIntegrity {
    public static func verify(url: URL, expectedSHA256: String) throws {
        guard expectedSHA256.count == 64,
              expectedSHA256.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0) }) else {
            throw ModelIntegrityError.invalidExpectedHash
        }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var hasher = SHA256()
        while let chunk = try file.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard actual.caseInsensitiveCompare(expectedSHA256) == .orderedSame else {
            throw ModelIntegrityError.hashMismatch
        }
    }
}
