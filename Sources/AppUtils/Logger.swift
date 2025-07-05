//
//  Logger.swift
//  AppUtils
//
//  Created by Vladyslav Semenchenko on 27/05/2025.
//

import Foundation

public class Logger {

    private static var path: String?

    public static func log(_ message: String) {
        print(message)
        if path == nil {
            let path = logUrl()
            try? "".write(toFile: path, atomically: true, encoding: .utf8)
            self.path = path
        }
        guard let path = path else { return }
        let text = try? String(contentsOf: URL(fileURLWithPath: path))
        let dateFormatter = DateFormatter()

        // Set the date format
        dateFormatter.dateFormat = "dd.MM.yyyy HH:mm:ss"

        // Create a date object
        let date = Date()

        // Convert the date to a string
        let dateString = dateFormatter.string(from: date)

        try? ((text ?? "") + "\n" + "\(dateString) " + message).write(toFile: path, atomically: true, encoding: .utf8)
    }

    public static func logUrl(appLaunchCount: Int) -> String {
        let dateFormatter = DateFormatter()

        // Set the date format
        dateFormatter.dateFormat = "dd.MM.yyyy"

        // Create a date object
        let date = Date()

        // Convert the date to a string
        let dateString = dateFormatter.string(from: date)

        let suffix = appLaunchCount % 3
        return NSTemporaryDirectory() + "\(dateString)_\(suffix)_log.txt"
    }

    public static func allLogsPaths() -> [String] {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(atPath: NSTemporaryDirectory())
        var paths = [String]()
        while let element = enumerator?.nextObject() as? String {
            if element.contains("_log.txt") {
                paths.append(NSTemporaryDirectory() + element)
            }
        }
        return paths
    }

    public static func logUrl() -> String {
        return logUrl(appLaunchCount: 0)
    }
}
