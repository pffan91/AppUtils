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

    // MARK: - Static

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

    public static func verbose(_ msg: String, usePrint: Bool = false) {
#if DEBUG
        if usePrint {
            print("\(printPrefix) |◽️ \(msg)")
        } else {
            NSLog("|◽️ \(msg)")
        }
#endif
    }

    public static func star(_ msg: String) {
#if DEBUG
        NSLog("|⭐️ \(msg)")
#endif
    }

    public static func state(_ msg: String) {
#if DEBUG
        NSLog("|🎲 \(msg)")
#endif
    }

    public static func user(_ msg: String) {
        // 👤👨‍💻
#if DEBUG
        NSLog("|😀 \(msg)")
#endif
    }

    public static func url(_ msg: String) {
#if DEBUG
        NSLog("|🌎 \(msg)")
#endif
    }

    public static func time(_ msg: String) {
#if DEBUG
        NSLog("|🕑 \(msg)")
#endif
    }

    public static func request(_ msg: String, usePrint: Bool = false) {
        // 🔼📡
#if DEBUG
        if usePrint {
            print("\(printPrefix) |📡 \(msg)")
        } else {
            NSLog("|📡 \(msg)")
        }
#endif
    }

    public static func response(_ msg: String, usePrint: Bool = false) {
        // 🔽🔻📦
#if DEBUG
        if usePrint {
            print("\(printPrefix) |📦 \(msg)")
        } else {
            NSLog("|📦 \(msg)")
        }
#endif
    }

    public static func debug(_ msg: String, usePrint: Bool = false) {
#if DEBUG
        if usePrint {
            print("\(printPrefix) |◾️ \(msg)")
        } else {
            NSLog("|◾️ \(msg)")
        }
#endif
    }

    public static func info(_ msg: String, usePrint: Bool = false) {
        if usePrint {
#if DEBUG
            print("\(printPrefix) |🔷 \(msg)")
#endif
        } else {
            NSLog("|🔷 \(msg)")
        }
    }

    public static func warn(_ msg: String, usePrint: Bool = false) {
        // ⚠️
        if usePrint {
#if DEBUG
            print("\(printPrefix) |🔶 \(msg)")
#endif
        } else {
            NSLog("|🔶 \(msg)")
        }
    }

    public static func error(_ msg: String, usePrint: Bool = false) {
        // ❗️
        if usePrint {
#if DEBUG
            print("\(printPrefix) |❌ \(msg)")
#endif
        } else {
            NSLog("|❌ \(msg)")
        }
    }

    // MARK: - Instance

    public func verbose(_ msg: String, usePrint: Bool = false) {
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

    public func request(_ msg: String, usePrint: Bool = false) {
        guard logLevel.rawValue <= LogLevel.verbose.rawValue else { return }
        ModuleLog.request("[\(moduleName)] \(msg)", usePrint: usePrint)
    }

    public func response(_ msg: String, usePrint: Bool = false) {
        guard logLevel.rawValue <= LogLevel.verbose.rawValue else { return }
        ModuleLog.response("[\(moduleName)] \(msg)", usePrint: usePrint)
    }

    public func debug(_ msg: String, usePrint: Bool = false) {
        guard logLevel.rawValue <= LogLevel.debug.rawValue else { return }
        ModuleLog.debug("[\(moduleName)] \(msg)", usePrint: usePrint)
    }

    public func info(_ msg: String, usePrint: Bool = false) {
        guard logLevel.rawValue <= LogLevel.info.rawValue else { return }
        ModuleLog.info("[\(moduleName)] \(msg)", usePrint: usePrint)
    }

    public func warn(_ msg: String, usePrint: Bool = false) {
        guard logLevel.rawValue <= LogLevel.warn.rawValue else { return }
        ModuleLog.warn("[\(moduleName)] \(msg)", usePrint: usePrint)
    }

    public func error(_ msg: String, usePrint: Bool = false) {
        guard logLevel.rawValue <= LogLevel.error.rawValue else { return }
        ModuleLog.error("[\(moduleName)] \(msg)", usePrint: usePrint)
    }

    public func error(_ error: Error, usePrint: Bool = false) {
        guard logLevel.rawValue <= LogLevel.error.rawValue else { return }
        ModuleLog.error("[\(moduleName)] \(String(describing: error))", usePrint: usePrint)
    }
}
