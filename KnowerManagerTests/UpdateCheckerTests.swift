import XCTest
@testable import KnowerManager

/// Тесты сравнения версий в UpdateChecker.
final class UpdateCheckerTests: XCTestCase {

    func testNewerPatchIsGreater() {
        XCTAssertGreaterThan(UpdateChecker.compare("3.0.1", "3.0"), 0)
    }

    func testOlderMajorIsLess() {
        XCTAssertLessThan(UpdateChecker.compare("v2.9", "3.0"), 0)
    }

    func testLeadingVIgnored() {
        XCTAssertEqual(UpdateChecker.compare("v3.0", "3.0"), 0)
    }

    func testTrailingZerosEqual() {
        XCTAssertEqual(UpdateChecker.compare("3.0", "3.0.0"), 0)
    }

    func testNumericNotLexicographic() {
        XCTAssertGreaterThan(UpdateChecker.compare("3.10", "3.9"), 0)
        XCTAssertGreaterThan(UpdateChecker.compare("v3.100", "3.99"), 0)
    }

    func testEqualVersions() {
        XCTAssertEqual(UpdateChecker.compare("3.0", "3.0"), 0)
    }

    func testSuffixLikeBetaTreatedAsNumericPrefix() {
        // "3.1-beta" нормализуется до [3, 1] (числовой префикс).
        XCTAssertEqual(UpdateChecker.compare("3.1-beta", "3.1"), 0)
    }
}

/// Тесты вспомогательных данных резервного копирования.
final class BackupManagerTests: XCTestCase {

    func testSuggestedFileNameHasPrefixAndZipExtension() {
        let name = BackupManager.suggestedFileName()
        XCTAssertTrue(name.hasPrefix("KnowerManager-Backup-"), "Получено: \(name)")
        XCTAssertTrue(name.hasSuffix(".zip"), "Получено: \(name)")
    }

    func testKnownFilesList() {
        XCTAssertEqual(BackupManager.knownFileNames,
                       ["profiles.json", "subscriptions.json", "ocr_history.json"])
    }

    func testDataDirectoryEndsWithAppFolder() {
        XCTAssertEqual(BackupManager.dataDirectory.lastPathComponent, "KnowerManager")
    }
}
