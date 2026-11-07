import Foundation
import MeetingDataKit
public protocol ReportRenderer { func render(_ artifact: ReportArtifact) throws -> Data }
public struct JSONReportRenderer: ReportRenderer {
    public init() {}
    public func render(_ artifact: ReportArtifact) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(artifact)
    }
}
