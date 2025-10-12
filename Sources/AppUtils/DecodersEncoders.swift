//
//  DecodersEncoders.swift
//  AppUtils
//
//  Created by Vladyslav Semenchenko on 12/10/2025.
//

import Foundation

public enum Decoders {
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
}

public enum Encoders {
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
}
