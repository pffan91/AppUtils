//
//  LogRotationPolicy.swift
//  AppUtils
//

import Foundation

/// Which log files survive, and when the current one is full.
///
/// Pure on purpose. The rules are the part worth pinning and the part that will be argued about
/// later; the file system around them is three calls. Keeping them separate is what makes them
/// checkable at all — a rule that only exists inside a function that also deletes files can only be
/// tested by deleting files.
///
/// The three limits come together because each one alone leaks (product decision, 02.09.2026): an
/// age limit does not survive one long session, a size limit does not survive weeks of short ones,
/// and the total is what catches whatever the first two let through.
public enum LogRotationPolicy {

    /// Anything last written more than this ago goes.
    public static let maxAge: TimeInterval = 3 * 24 * 60 * 60

    /// A file this big stops being written to and a new part is started.
    public static let maxFileBytes = 2 * 1024 * 1024

    /// Everything the logs may occupy together.
    public static let maxTotalBytes = 10 * 1024 * 1024

    public struct File: Equatable {

        public let path: String
        public let modified: Date
        public let size: Int

        public init(path: String, modified: Date, size: Int) {
            self.path = path
            self.modified = modified
            self.size = size
        }
    }

    /// The current file has no more room.
    public static func isFull(_ bytes: Int) -> Bool { bytes >= maxFileBytes }

    /// Which files to remove, oldest first.
    ///
    /// - Parameter keeping: the file being written to now. It is never deleted, however old or
    ///   large the rest of the set is — deleting the log of the session that is running is how you
    ///   lose the log of the session someone is about to complain about.
    public static func filesToDelete(_ files: [File], now: Date, keeping current: String?) -> [String] {
        let candidates = files.filter { $0.path != current }
        let oldestFirst = candidates.sorted { $0.modified < $1.modified }

        var doomed: [String] = []
        var survivors: [File] = []
        for file in oldestFirst {
            if now.timeIntervalSince(file.modified) > maxAge {
                doomed.append(file.path)
            } else {
                survivors.append(file)
            }
        }

        // The current file counts towards the total even though it cannot be deleted: it is real
        // bytes on a real disk, and leaving it out of the sum is how a 10 MB budget becomes 12.
        let currentSize = files.first { $0.path == current }?.size ?? 0
        var total = survivors.reduce(currentSize) { $0 + $1.size }
        var index = 0
        while total > maxTotalBytes, index < survivors.count {
            doomed.append(survivors[index].path)
            total -= survivors[index].size
            index += 1
        }
        return doomed
    }
}

/// How a log file is named, and how to get to the next part of it.
///
/// `<dd.MM.yyyy>_<launch % 3>_log.txt` for the first part of a run, then `_2`, `_3` … appended
/// before `_log`. The shape is unchanged from before rotation existed, because
/// `SupportManager.sortedLogFilePaths()` and `allLogFilePaths()` both find files by the `_log.txt`
/// ending and a rename would have made yesterday's logs invisible to the support upload.
public enum LogFileName {

    public static let suffix = "_log.txt"

    /// The part after this one. `…_0_log.txt` → `…_0_2_log.txt` → `…_0_3_log.txt`.
    public static func nextPart(after path: String) -> String {
        let directory = (path as NSString).deletingLastPathComponent
        let name = (path as NSString).lastPathComponent
        guard name.hasSuffix(suffix) else { return path }

        let stem = String(name.dropLast(suffix.count))
        let components = stem.split(separator: "_")
        var parts = components.map(String.init)

        // A trailing number that is not the launch suffix is the part counter. The launch suffix is
        // always there, so a stem of one component cannot be carrying one.
        if parts.count > 2, let part = Int(parts[parts.count - 1]) {
            parts[parts.count - 1] = String(part + 1)
        } else {
            parts.append("2")
        }
        let next = parts.joined(separator: "_") + suffix
        return directory.isEmpty ? next : (directory as NSString).appendingPathComponent(next)
    }

    /// Every part of `base` that exists, in the order they were written.
    public static func parts(of base: String, among files: [String]) -> [String] {
        guard base.hasSuffix(suffix) else { return [] }
        let stem = String(base.dropLast(suffix.count))
        return files
            .filter { $0 == base || ($0.hasPrefix(stem + "_") && $0.hasSuffix(suffix)) }
            .sorted { partNumber(of: $0) < partNumber(of: $1) }
    }

    /// `1` for the first part, `2` for `_2`, and so on. Used only to order parts of the same base.
    public static func partNumber(of path: String) -> Int {
        let name = (path as NSString).lastPathComponent
        guard name.hasSuffix(suffix) else { return 1 }
        let stem = String(name.dropLast(suffix.count))
        let parts = stem.split(separator: "_")
        guard parts.count > 2, let number = Int(parts[parts.count - 1]) else { return 1 }
        return number
    }
}
