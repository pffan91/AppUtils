//
//  AppUtils.swift
//  AppUtils
//
//  Created by Vladyslav Semenchenko on 26/10/2024.
//

import Foundation

public enum AppUtils {

    /// Create new JSON decoder with .millisecondsSince1970 date decoding strategy
    public static func newJSONDecoder(dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .millisecondsSince1970) -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStrategy
        return decoder
    }

    /// Shared JSON decoder with .millisecondsSince1970 date decoding strategy
    public static let jsonDecoder: JSONDecoder = {
        newJSONDecoder()
    }()

    /// Shared JSON decoder with .iso8601 date decoding strategy
    public static let jsonISO8601Decoder: JSONDecoder = {
        newJSONDecoder(dateDecodingStrategy: .iso8601)
    }()

    /// Create new JSON encoder with .millisecondsSince1970 date encoding strategy
    public static func newJSONEncoder(dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .millisecondsSince1970) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = dateEncodingStrategy
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }

    /// Shared JSON encoder with .millisecondsSince1970 date encoding strategy
    public static let jsonEncoder: JSONEncoder = {
        newJSONEncoder()
    }()

    /// Shared JSON encoder with .iso8601 date encoding strategy
    public static let jsonISO8601Encoder: JSONEncoder = {
        newJSONEncoder(dateEncodingStrategy: .iso8601)
    }()

    public static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.decimalSeparator = "."
        formatter.numberStyle = .decimal
        formatter.minimumIntegerDigits = 1
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    public static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    public static func formatPrice(_ priceString: String) -> String {
        guard let price = Double(priceString) else { return priceString }

        let isWholeNumber = floor(price) == price

        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.decimalSeparator = Locale.current.decimalSeparator ?? "."

        if isWholeNumber {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        }

        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }

    /// Must include country code.
    public static func formattedPhoneNumber(_ phoneNumber: String) -> String {
        let firstPart = "+" + phoneNumber.prefix(1) + " (" + phoneNumber.dropFirst(1).prefix(3) + ") "
        let formatted = firstPart + phoneNumber.dropFirst(4).prefix(3) + "-" + phoneNumber.dropFirst(7).prefix(2) + "-" + phoneNumber.dropFirst(9)
        return formatted
    }

    public static func formattedTime(for seconds: Int, includeUnits: Bool = true, hoursShortString: String, minutesShortString: String) -> String {
        let hours = seconds / 3600
        let remainingSecondsAfterHours = seconds % 3600
        let minutes = remainingSecondsAfterHours / 60
        let remainingSeconds = remainingSecondsAfterHours % 60

        if includeUnits {
            if hours > 0 {
                let hoursString = hoursShortString
                let minutesString = minutesShortString
                return "\(hours) \(hoursString) \(minutes) \(minutesString)".trimmingCharacters(in: .whitespaces)
            } else {
                let minutesString = minutesShortString
                return String(format: "%d %@", minutes, minutesString)
            }
        } else {
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
            } else {
                return String(format: "%02d:%02d", minutes, remainingSeconds)
            }
        }
    }

    public static func seconds(from timeString: String) -> Int? {
        // Split the time string into components using ":" as the delimiter
        let components = timeString.split(separator: ":").map { String($0) }

        // Ensure the components are valid integers
        guard components.allSatisfy({ Int($0) != nil }) else {
            return nil // Return nil if any component is not a valid integer
        }

        // Convert components to integers
        let timeComponents = components.compactMap { Int($0) }

        // Calculate total seconds based on the number of components
        switch timeComponents.count {
        case 1:
            // Format: "seconds"
            return timeComponents[0]
        case 2:
            // Format: "minutes:seconds"
            let minutes = timeComponents[0]
            let seconds = timeComponents[1]
            return minutes * 60 + seconds
        case 3:
            // Format: "hours:minutes:seconds"
            let hours = timeComponents[0]
            let minutes = timeComponents[1]
            let seconds = timeComponents[2]
            return hours * 3600 + minutes * 60 + seconds
        default:
            // Invalid format
            return nil
        }
    }

    public static func convertVersionToServerString(version: String, build: String) -> String {
        let versionCleaned = version.replacingOccurrences(of: ".", with: "")
        let versionPadded = (String(repeating: "0", count: max(0, 4 - versionCleaned.count)) + versionCleaned).prefix(4)
        let buildPadded = (String(repeating: "0", count: max(0, 4 - build.count)) + build).prefix(4)
        return "\(versionPadded)\(buildPadded)"
    }
}
