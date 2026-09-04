//
//  LogRotationTests.swift
//  AppUtilsTests
//

import XCTest
@testable import AppUtils

/// Three rules decide which logs survive: three days, two megabytes a file, ten megabytes in total.
/// They are together because each one alone leaks — an age limit does not survive one long session,
/// a size limit does not survive weeks of short ones, and the total catches the rest.
final class LogRotationPolicyTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    private func file(_ name: String, daysAgo: Double = 0, mb: Double = 0) -> LogRotationPolicy.File {
        LogRotationPolicy.File(path: name,
                               modified: now.addingTimeInterval(-daysAgo * 24 * 60 * 60),
                               size: Int(mb * 1024 * 1024))
    }

    // MARK: - Age

    func test_filesOlderThanThreeDaysGo() {
        let doomed = LogRotationPolicy.filesToDelete([file("old", daysAgo: 4, mb: 0.1),
                                                      file("fresh", daysAgo: 1, mb: 0.1)],
                                                     now: now, keeping: nil)

        XCTAssertEqual(doomed, ["old"])
    }

    /// Three days means three days. A file written seventy-one hours ago is inside the window, and
    /// an off-by-one here silently halves how far back support can look.
    func test_aFileJustInsideTheWindowStays() {
        let doomed = LogRotationPolicy.filesToDelete([file("edge", daysAgo: 2.99, mb: 0.1)],
                                                     now: now, keeping: nil)

        XCTAssertTrue(doomed.isEmpty)
    }

    // MARK: - Total size

    func test_theOldestGoFirstWhenTheTotalIsTooBig() {
        let doomed = LogRotationPolicy.filesToDelete([file("newest", daysAgo: 0, mb: 5),
                                                      file("middle", daysAgo: 1, mb: 5),
                                                      file("oldest", daysAgo: 2, mb: 5)],
                                                     now: now, keeping: nil)

        XCTAssertEqual(doomed, ["oldest"], "15 MB down to 10 costs exactly the oldest file")
    }

    func test_nothingGoesWhenTheTotalFits() {
        let doomed = LogRotationPolicy.filesToDelete([file("a", mb: 4), file("b", daysAgo: 1, mb: 4)],
                                                     now: now, keeping: nil)

        XCTAssertTrue(doomed.isEmpty)
    }

    /// The session running right now is the one whose log someone is about to ask for.
    func test_theFileBeingWrittenIsNeverDeleted() {
        let doomed = LogRotationPolicy.filesToDelete([file("current", daysAgo: 9, mb: 9),
                                                      file("other", daysAgo: 1, mb: 9)],
                                                     now: now, keeping: "current")

        XCTAssertEqual(doomed, ["other"])
    }

    /// It cannot be deleted, but it is still bytes on the disk. Leaving it out of the sum is how a
    /// 10 MB budget quietly becomes 19.
    /// Verified trace: start the total from `0` instead of `currentSize` → this test and
    /// `test_theFileBeingWrittenIsNeverDeleted` both go red, and nothing else does.
    func test_theCurrentFileCountsTowardsTheTotal() {
        let doomed = LogRotationPolicy.filesToDelete([file("current", mb: 9),
                                                      file("other", daysAgo: 1, mb: 9)],
                                                     now: now, keeping: "current")

        XCTAssertEqual(doomed, ["other"])
    }

    // MARK: - One file's ceiling

    func test_twoMegabytesFillsAFile() {
        XCTAssertFalse(LogRotationPolicy.isFull(2 * 1024 * 1024 - 1))
        XCTAssertTrue(LogRotationPolicy.isFull(2 * 1024 * 1024))
    }
}

/// The names have to keep their shape: `SupportManager.sortedLogFilePaths()` and `allLogFilePaths()`
/// both find files by the `_log.txt` ending, so a renaming scheme would have made every existing
/// log invisible to the support upload on the day it shipped.
final class LogFileNameTests: XCTestCase {

    func test_theSecondPartIsNumberedTwo() {
        XCTAssertEqual(LogFileName.nextPart(after: "/tmp/04.09.2026_0_log.txt"),
                       "/tmp/04.09.2026_0_2_log.txt")
    }

    func test_partsKeepCounting() {
        XCTAssertEqual(LogFileName.nextPart(after: "/tmp/04.09.2026_0_2_log.txt"),
                       "/tmp/04.09.2026_0_3_log.txt")
        XCTAssertEqual(LogFileName.nextPart(after: "/tmp/04.09.2026_2_9_log.txt"),
                       "/tmp/04.09.2026_2_10_log.txt")
    }

    /// The launch suffix is a number too, and reading it as a part counter would turn every
    /// first-part file into a second-part one of the wrong launch.
    func test_theLaunchSuffixIsNotMistakenForAPartCounter() {
        XCTAssertEqual(LogFileName.nextPart(after: "/tmp/04.09.2026_1_log.txt"),
                       "/tmp/04.09.2026_1_2_log.txt")
        XCTAssertEqual(LogFileName.partNumber(of: "/tmp/04.09.2026_1_log.txt"), 1)
        XCTAssertEqual(LogFileName.partNumber(of: "/tmp/04.09.2026_1_2_log.txt"), 2)
    }

    func test_everyPartOfTodaysFileIsFoundInOrder() {
        let all = ["/tmp/04.09.2026_0_log.txt",
                   "/tmp/04.09.2026_0_3_log.txt",
                   "/tmp/04.09.2026_0_2_log.txt",
                   "/tmp/04.09.2026_1_log.txt",
                   "/tmp/03.09.2026_0_log.txt"]

        XCTAssertEqual(LogFileName.parts(of: "/tmp/04.09.2026_0_log.txt", among: all),
                       ["/tmp/04.09.2026_0_log.txt",
                        "/tmp/04.09.2026_0_2_log.txt",
                        "/tmp/04.09.2026_0_3_log.txt"])
    }

    func test_anotherLaunchesFileIsNotAPartOfThisOne() {
        let all = ["/tmp/04.09.2026_0_log.txt", "/tmp/04.09.2026_1_log.txt"]

        XCTAssertEqual(LogFileName.parts(of: "/tmp/04.09.2026_0_log.txt", among: all),
                       ["/tmp/04.09.2026_0_log.txt"])
    }
}

/// What the rules are for. These write real files, in a directory of their own — the process-wide
/// temporary one is shared with everything else running.
final class ModuleLogFileWritingTests: XCTestCase {

    private var directory = ""

    override func setUp() {
        super.setUp()
        directory = NSTemporaryDirectory() + "modulelog-tests-\(UUID().uuidString)/"
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        ModuleLog.directory = directory
    }

    override func tearDown() {
        ModuleLog.disableFileLogging()
        try? FileManager.default.removeItem(atPath: directory)
        ModuleLog.directory = NSTemporaryDirectory()
        super.tearDown()
    }

    /// The point of the whole change: a line is added to what is there, not written over it.
    func test_everyLineIsKept() {
        ModuleLog.enableFileLogging(appLaunchCount: 0)

        for index in 0..<200 { ModuleLog.info("line \(index)", usePrint: false) }

        let content = ModuleLog.currentLogContent() ?? ""
        XCTAssertTrue(content.contains("line 0"), "the first line must survive the two hundredth")
        XCTAssertTrue(content.contains("line 199"))
        XCTAssertEqual(content.components(separatedBy: "line ").count - 1, 200)
    }

    /// `currentLogContent()` is read right after something went wrong, and the lines describing it
    /// are the ones still in flight. Without the queue hop inside it, an asynchronous writer would
    /// drop exactly those.
    /// Verified trace: read the file without going through `ioQueue.sync` → three of the five
    /// tests in this class go red, not one. Every read here is a read of something just written,
    /// which is the point: that is also true of every read the app makes.
    func test_aReadSeesTheLineWrittenAMomentBefore() {
        ModuleLog.enableFileLogging(appLaunchCount: 0)

        ModuleLog.info("the very last thing that happened", usePrint: false)

        XCTAssertTrue((ModuleLog.currentLogContent() ?? "").contains("the very last thing that happened"))
    }

    func test_aFullFileIsFollowedByANewPart() {
        ModuleLog.enableFileLogging(appLaunchCount: 0)
        let base = directory + "\(dayString())_0_log.txt"

        // A line of ~2 KB, a thousand of them: past the 2 MB ceiling and into the next part.
        let padding = String(repeating: "x", count: 2048)
        for index in 0..<1100 { ModuleLog.info("\(index) \(padding)", usePrint: false) }
        _ = ModuleLog.currentLogContent()

        let parts = LogFileName.parts(of: base, among: ModuleLog.allLogFilePaths())
        XCTAssertGreaterThan(parts.count, 1, "2 MB has to end a file, not grow it")
        let firstPartSize = ((try? FileManager.default.attributesOfItem(atPath: parts[0]))?[.size] as? Int) ?? 0
        XCTAssertLessThan(firstPartSize, 3 * 1024 * 1024, "the ceiling is 2 MB plus at most one line")
    }

    /// A relaunch inside the same day and launch suffix goes on with the file it left, rather than
    /// starting a part it does not need.
    func test_relaunchingContinuesTheSameFile() {
        ModuleLog.enableFileLogging(appLaunchCount: 0)
        ModuleLog.info("before the relaunch", usePrint: false)
        _ = ModuleLog.currentLogContent()
        ModuleLog.disableFileLogging()

        ModuleLog.enableFileLogging(appLaunchCount: 0)
        ModuleLog.info("after the relaunch", usePrint: false)

        let content = ModuleLog.currentLogContent() ?? ""
        XCTAssertTrue(content.contains("before the relaunch"))
        XCTAssertTrue(content.contains("after the relaunch"))
    }

    func test_logsOlderThanThreeDaysAreGoneAfterALaunch() {
        let stale = directory + "01.01.2020_0_log.txt"
        FileManager.default.createFile(atPath: stale, contents: Data("old".utf8))
        try? FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)],
                                               ofItemAtPath: stale)

        ModuleLog.enableFileLogging(appLaunchCount: 0)
        _ = ModuleLog.currentLogContent()

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale))
    }

    private func dayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: Date())
    }
}
