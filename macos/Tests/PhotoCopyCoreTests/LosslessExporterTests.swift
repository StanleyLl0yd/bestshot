import Foundation
import XCTest
@testable import PhotoCopyCore

final class LosslessExporterTests: XCTestCase {
    func testCopiesPreserveOriginalBytesAndAvoidFilenameCollisions() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let firstDir = root.appendingPathComponent("a")
        let secondDir = root.appendingPathComponent("b")
        let exportDir = root.appendingPathComponent("export")
        try fm.createDirectory(at: firstDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: secondDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: exportDir, withIntermediateDirectories: true)
        let original1 = firstDir.appendingPathComponent("same.jpg")
        let original2 = secondDir.appendingPathComponent("same.jpg")
        let data1 = Data([0, 2, 255, 9, 7])
        let data2 = Data([11, 18, 27, 36])
        try data1.write(to: original1)
        try data2.write(to: original2)
        try Data([99]).write(to: exportDir.appendingPathComponent("same.jpg"))
        let copies = try LosslessExporter.copy([original1, original2], into: exportDir)
        XCTAssertEqual(copies.map(\.lastPathComponent), ["same-1.jpg", "same-2.jpg"])
        XCTAssertEqual(try Data(contentsOf: copies[0]), data1)
        XCTAssertEqual(try Data(contentsOf: copies[1]), data2)
        XCTAssertEqual(try Data(contentsOf: original1), data1)
        XCTAssertEqual(try Data(contentsOf: original2), data2)
        XCTAssertEqual(try Data(contentsOf: exportDir.appendingPathComponent("same.jpg")), Data([99]))
    }

    func testPartialFailureNeverMutatesSources() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let original = root.appendingPathComponent("photo.png")
        try Data([1, 2, 3]).write(to: original)
        let other = root.appendingPathComponent("missing.png")
        do {
            _ = try LosslessExporter.copy([original, other], into: root)
            XCTFail("Expected error")
        } catch let failure as ExportFailure {
            XCTAssertEqual(failure.completed.count, 1)
            XCTAssertEqual(try Data(contentsOf: original), Data([1, 2, 3]))
            XCTAssertEqual(try Data(contentsOf: failure.completed[0]), Data([1, 2, 3]))
        }
    }
}
