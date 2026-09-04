//
//  ModuleLog.swift
//  AppUtils
//
//  Created by Vladyslav Semenchenko on 12/01/2025.
//

import Foundation

public struct ModuleLog {

    let moduleName: String

    public enum LogLevel: Int {
        case verbose, debug, info, warn, error, off
    }

    var logLevel: LogLevel

    public init(moduleName: String, level: LogLevel = .verbose) {
        self.moduleName = moduleName
        self.logLevel = level
    }

    // MARK: -

    private static let printDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
        return formatter
    }()

    private static var printPrefix: String {
        var tid: UInt64 = 0
        pthread_threadid_np(nil, &tid)
        return "\(printDateFormatter.string(from: Date())) \(Bundle.main.infoDictionary?[kCFBundleNameKey as String] ?? "")[\(getpid()):\(tid)]"
    }

    // MARK: - File Logging

    /// Where the log is written, and the one place that touches the file.
    ///
    /// The writer used to read the whole file, append one line and write the whole file back — and
    /// atomically, which is a full copy plus a rename. Per line. On the calling thread. The cost of
    /// a line grew with the size of the file, so the bytes written over a session grew with its
    /// square: five thousand 200-byte lines make a 1 MB file and about 2.5 GB of writing. Now the
    /// line is appended through an open handle on a queue of its own.
    ///
    /// The two numbers people quoted at each other were both right and about different things — the
    /// file was megabytes, the writing was gigabytes. Only the second one was the problem.
    private static let ioQueue = DispatchQueue(label: "com.autoexpert.apputils.modulelog", qos: .utility)

    /// Touched on `ioQueue` only.
    private static var handle: FileHandle?
    private static var handlePath: String?
    private static var bytesInFile = 0

    /// `filePath` and `isFileLoggingEnabled` are read from every thread that logs and written from
    /// the main thread at launch — and now also from `ioQueue`, when a file fills up and the next
    /// part takes over. That is a race the old synchronous writer did not have to answer for.
    private static let stateLock = NSLock()
    private static var _filePath: String?
    private static var _isFileLoggingEnabled = false

    private static var filePath: String? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _filePath }
        set { stateLock.lock(); defer { stateLock.unlock() }; _filePath = newValue }
    }

    private static var isFileLoggingEnabled: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _isFileLoggingEnabled }
        set { stateLock.lock(); defer { stateLock.unlock() }; _isFileLoggingEnabled = newValue }
    }

    private static var logFileDateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        return dateFormatter
    }

    /// Where the files live. Overridable so the rotation can be exercised in a directory of its own
    /// instead of the process-wide temporary one, which tests share with everything else.
    static var directory: String = NSTemporaryDirectory()

    public static func enableFileLogging(appLaunchCount: Int = 0) {
        let base = logFileUrl(appLaunchCount: appLaunchCount)
        let path = startingPart(for: base)

        if !FileManager.default.fileExists(atPath: path) {
            try? "".write(toFile: path, atomically: true, encoding: .utf8)
        }

        filePath = path
        isFileLoggingEnabled = true
        ioQueue.async {
            closeHandle()
            bytesInFile = fileSize(path)
            // Cheap and once per launch, which is why it lives here rather than on a timer or on
            // the write path. Nothing else in the app knows enough to do it.
            prune(keeping: path)
        }
    }

    public static func disableFileLogging() {
        isFileLoggingEnabled = false
        filePath = nil
        ioQueue.async { closeHandle() }
    }

    public static func logFileUrl(appLaunchCount: Int = 0) -> String {
        let dateString = logFileDateFormatter.string(from: Date())
        let suffix = appLaunchCount % 3
        return directory + "\(dateString)_\(suffix)\(LogFileName.suffix)"
    }

    public static func allLogFilePaths() -> [String] {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(atPath: directory)
        var paths = [String]()
        while let element = enumerator?.nextObject() as? String {
            if element.hasSuffix(LogFileName.suffix) {
                paths.append(directory + element)
            }
        }
        return paths
    }

    /// Waits for whatever is queued before reading.
    ///
    /// It has to. This is what the support upload and the shake-to-send diagnostic read, and both
    /// are asked for right after something went wrong — the lines describing it are the ones still
    /// in flight. An asynchronous writer without this hop would drop exactly them.
    public static func currentLogContent() -> String? {
        guard let path = filePath else { return nil }
        return ioQueue.sync {
            try? handle?.synchronize()
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            return try? String(contentsOfFile: path, encoding: .utf8)
        }
    }

    private static func writeToFile(_ message: String) {
        guard isFileLoggingEnabled else { return }
        // Built here, not on the writer queue: the prefix carries the id of the thread that
        // produced the line and the moment it was produced, and both would name the queue instead.
        let line = "\n\(printPrefix) " + message
        ioQueue.async { append(line) }
    }

    // MARK: - File Logging — on ioQueue only

    /// Reads the destination when it writes, not when it was asked to.
    ///
    /// The first version captured the path at the call site and a test caught what that costs:
    /// a burst of logging enqueues a thousand blocks in a moment, every one of them holding the
    /// path from before the file filled up, so the rollover happened over and over and every line
    /// still went into the file it was supposed to have left.
    private static func append(_ line: String) {
        guard let path = filePath,
              let data = line.data(using: .utf8),
              let handle = openHandle(for: path) else { return }
        // `write(contentsOf:)` reports a full disk instead of raising an Objective-C exception
        // through Swift, where it cannot be caught. The package still supports iOS 13.0.
        if #available(iOS 13.4, macOS 10.15.4, *) {
            try? handle.write(contentsOf: data)
        } else {
            handle.write(data)
        }
        bytesInFile += data.count

        guard LogRotationPolicy.isFull(bytesInFile) else { return }
        closeHandle()
        let next = LogFileName.nextPart(after: path)
        filePath = next
        bytesInFile = 0
    }

    private static func openHandle(for path: String) -> FileHandle? {
        if let handle, handlePath == path { return handle }
        closeHandle()
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        guard let opened = FileHandle(forWritingAtPath: path) else { return nil }
        opened.seekToEndOfFile()
        handle = opened
        handlePath = path
        return opened
    }

    private static func closeHandle() {
        try? handle?.close()
        handle = nil
        handlePath = nil
    }

    private static func fileSize(_ path: String) -> Int {
        ((try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int) ?? 0
    }

    /// The part to carry on writing: the last one that exists, or the next one when it is full.
    ///
    /// A relaunch inside the same day and launch-suffix continues the file it left rather than
    /// picking up a full one and immediately rolling it.
    private static func startingPart(for base: String) -> String {
        let existing = LogFileName.parts(of: base, among: allLogFilePaths())
        guard let last = existing.last else { return base }
        return LogRotationPolicy.isFull(fileSize(last)) ? LogFileName.nextPart(after: last) : last
    }

    private static func prune(keeping current: String) {
        let manager = FileManager.default
        let files = allLogFilePaths().map { path -> LogRotationPolicy.File in
            let attributes = try? manager.attributesOfItem(atPath: path)
            return LogRotationPolicy.File(path: path,
                                          modified: (attributes?[.modificationDate] as? Date) ?? .distantPast,
                                          size: (attributes?[.size] as? Int) ?? 0)
        }
        for path in LogRotationPolicy.filesToDelete(files, now: Date(), keeping: current) {
            try? manager.removeItem(atPath: path)
        }
    }

        // MARK: - Static

        public static func verbose(_ msg: String, usePrint: Bool = true) {
#if DEBUG
            if usePrint {
                print("\(printPrefix) |◽️ \(msg)")
            } else {
                NSLog("|◽️ \(msg)")
            }
#endif
            writeToFile("|◽️ \(msg)")
        }

        public static func star(_ msg: String, usePrint: Bool = true) {
#if DEBUG
            if usePrint {
                print("\(printPrefix) |⭐️ \(msg)")
            } else {
                NSLog("|⭐️ \(msg)")
            }
#endif
            writeToFile("|⭐️ \(msg)")
        }

        public static func state(_ msg: String, usePrint: Bool = true) {
#if DEBUG
            if usePrint {
                print("\(printPrefix) |🎲 \(msg)")
            } else {
                NSLog("|🎲 \(msg)")
            }
#endif
            writeToFile("|🎲 \(msg)")
        }

        public static func user(_ msg: String, usePrint: Bool = true) {
            // 👤👨‍💻
#if DEBUG
            if usePrint {
                print("\(printPrefix) |😀 \(msg)")
            } else {
                NSLog("|😀 \(msg)")
            }
#endif
            writeToFile("|😀 \(msg)")
        }

        public static func url(_ msg: String, usePrint: Bool = true) {
#if DEBUG
            if usePrint {
                print("\(printPrefix) |🌎 \(msg)")
            } else {
                NSLog("|🌎 \(msg)")
            }
#endif
            writeToFile("|🌎 \(msg)")
        }

        public static func time(_ msg: String, usePrint: Bool = true) {
#if DEBUG
            if usePrint {
                print("\(printPrefix) |🕑 \(msg)")
            } else {
                NSLog("|🕑 \(msg)")
            }
#endif
            writeToFile("|🕑 \(msg)")
        }

        public static func request(_ msg: String, usePrint: Bool = true) {
            // 🔼📡
#if DEBUG
            if usePrint {
                print("\(printPrefix) |📡 \(msg)")
            } else {
                NSLog("|📡 \(msg)")
            }
#endif
            writeToFile("|📡 \(msg)")
        }

        public static func response(_ msg: String, usePrint: Bool = true) {
            // 🔽🔻📦
#if DEBUG
            if usePrint {
                print("\(printPrefix) |📦 \(msg)")
            } else {
                NSLog("|📦 \(msg)")
            }
#endif
            writeToFile("|📦 \(msg)")
        }

        public static func debug(_ msg: String, usePrint: Bool = true) {
#if DEBUG
            if usePrint {
                print("\(printPrefix) |◾️ \(msg)")
            } else {
                NSLog("|◾️ \(msg)")
            }
#endif
            writeToFile("|◾️ \(msg)")
        }

        public static func info(_ msg: String, usePrint: Bool = true) {
            if usePrint {
#if DEBUG
                print("\(printPrefix) |🔷 \(msg)")
#endif
            } else {
                NSLog("|🔷 \(msg)")
            }
            writeToFile("|🔷 \(msg)")
        }

        public static func warn(_ msg: String, usePrint: Bool = true) {
            // ⚠️
            if usePrint {
#if DEBUG
                print("\(printPrefix) |🔶 \(msg)")
#endif
            } else {
                NSLog("|🔶 \(msg)")
            }
            writeToFile("|🔶 \(msg)")
        }

        public static func error(_ msg: String, usePrint: Bool = true) {
            // ❗️
            if usePrint {
#if DEBUG
                print("\(printPrefix) |❌ \(msg)")
#endif
            } else {
                NSLog("|❌ \(msg)")
            }
            writeToFile("|❌ \(msg)")
        }

        // MARK: - Instance

        public func verbose(_ msg: String, usePrint: Bool = true) {
            guard logLevel.rawValue <= LogLevel.verbose.rawValue else { return }
            ModuleLog.verbose("[\(moduleName)] \(msg)", usePrint: usePrint)
        }

        public func star(_ msg: String) {
            guard logLevel.rawValue <= LogLevel.verbose.rawValue else { return }
            ModuleLog.star("[\(moduleName)] \(msg)")
        }

        public func state(_ msg: String) {
            guard logLevel.rawValue <= LogLevel.verbose.rawValue else { return }
            ModuleLog.state("[\(moduleName)] \(msg)")
        }

        public func user(_ msg: String) {
            guard logLevel.rawValue <= LogLevel.verbose.rawValue else { return }
            ModuleLog.user("[\(moduleName)] \(msg)")
        }

        public func url(_ msg: String) {
            guard logLevel.rawValue <= LogLevel.verbose.rawValue else { return }
            ModuleLog.url("[\(moduleName)] \(msg)")
        }

        public func time(_ msg: String) {
            guard logLevel.rawValue <= LogLevel.verbose.rawValue else { return }
            ModuleLog.time("[\(moduleName)] \(msg)")
        }

        public func request(_ msg: String, usePrint: Bool = true) {
            guard logLevel.rawValue <= LogLevel.verbose.rawValue else { return }
            ModuleLog.request("[\(moduleName)] \(msg)", usePrint: usePrint)
        }

        public func response(_ msg: String, usePrint: Bool = true) {
            guard logLevel.rawValue <= LogLevel.verbose.rawValue else { return }
            ModuleLog.response("[\(moduleName)] \(msg)", usePrint: usePrint)
        }

        public func debug(_ msg: String, usePrint: Bool = true) {
            guard logLevel.rawValue <= LogLevel.debug.rawValue else { return }
            ModuleLog.debug("[\(moduleName)] \(msg)", usePrint: usePrint)
        }

        public func info(_ msg: String, usePrint: Bool = true) {
            guard logLevel.rawValue <= LogLevel.info.rawValue else { return }
            ModuleLog.info("[\(moduleName)] \(msg)", usePrint: usePrint)
        }

        public func warn(_ msg: String, usePrint: Bool = true) {
            guard logLevel.rawValue <= LogLevel.warn.rawValue else { return }
            ModuleLog.warn("[\(moduleName)] \(msg)", usePrint: usePrint)
        }

        public func error(_ msg: String, usePrint: Bool = true) {
            guard logLevel.rawValue <= LogLevel.error.rawValue else { return }
            ModuleLog.error("[\(moduleName)] \(msg)", usePrint: usePrint)
        }

        public func error(_ error: Error, usePrint: Bool = true) {
            guard logLevel.rawValue <= LogLevel.error.rawValue else { return }
            ModuleLog.error("[\(moduleName)] \(String(describing: error))", usePrint: usePrint)
        }
    }
