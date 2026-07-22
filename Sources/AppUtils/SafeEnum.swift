//
//  SafeEnum.swift
//  AppUtils
//

import Foundation

/// A decoding wrapper for string-backed enums that tolerates unknown raw values.
/// An unrecognized value decodes to a `nil` `value` instead of throwing,
/// so a single unknown enum case does not fail decoding of the whole container.
///
/// Note:
/// - Any non-decodable value is swallowed, not just an unknown string: a number,
///   an object, or `null` in place of the value also decodes to `nil`. If the server
///   breaks serialization for a known case, the element silently becomes `nil`.
/// - The element itself stays in the container with `value == nil`;
///   filtering such elements out is up to the calling code.
/// - A missing key still fails decoding: that error is thrown before `init(from:)`
///   is reached. Use `decodeIfPresent` or an optional property for absent keys.
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

extension SafeEnum: Sendable where StringEnum: Sendable {}

extension SafeEnum: Equatable where StringEnum: Equatable {}

extension SafeEnum: Hashable where StringEnum: Hashable {}
