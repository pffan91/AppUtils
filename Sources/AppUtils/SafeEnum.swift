//
//  SafeEnum.swift
//  AppUtils
//

import Foundation

/// A decoding wrapper for string-backed enums that tolerates unknown raw values.
/// An unrecognized value decodes to a `nil` `value` instead of throwing,
/// so a single unknown enum case does not fail decoding of the whole container.
public struct SafeEnum<StringEnum: RawRepresentable>: Decodable where StringEnum.RawValue == String {

    private static var log: ModuleLog { ModuleLog(moduleName: "SafeEnum") }

    public let value: StringEnum?

    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            value = StringEnum(rawValue: rawValue)
            if value == nil {
                SafeEnum.log.warn("Unknown raw value \"\(rawValue)\" for \(StringEnum.self)")
            }
        } catch {
            SafeEnum.log.error("Failed to decode raw value for \(StringEnum.self): \(error)")
            value = nil
        }
    }
}
