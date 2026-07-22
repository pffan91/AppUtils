import XCTest
@testable import AppUtils

final class SafeEnumTests: XCTestCase {

    private enum SourceType: String, Decodable {
        case autoteka
        case sravni
    }

    func testDecodesKnownValue() throws {
        let data = Data("\"autoteka\"".utf8)
        let decoded = try JSONDecoder().decode(SafeEnum<SourceType>.self, from: data)
        XCTAssertEqual(decoded.value, .autoteka)
    }

    func testDecodesUnknownValueAsNilWithoutThrowing() throws {
        let data = Data("\"unknown_source\"".utf8)
        let decoded = try JSONDecoder().decode(SafeEnum<SourceType>.self, from: data)
        XCTAssertNil(decoded.value)
    }

    func testDecodesArrayWithUnknownValuesKeepingKnownOnes() throws {
        let data = Data("[\"autoteka\", \"unknown_source\", \"sravni\"]".utf8)
        let decoded = try JSONDecoder().decode([SafeEnum<SourceType>].self, from: data)
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded.compactMap { $0.value }, [.autoteka, .sravni])
    }

    func testDecodesNumberValueAsNilWithoutThrowing() throws {
        let data = Data("42".utf8)
        let decoded = try JSONDecoder().decode(SafeEnum<SourceType>.self, from: data)
        XCTAssertNil(decoded.value)
    }

    func testDecodesBoolValueAsNilWithoutThrowing() throws {
        let data = Data("true".utf8)
        let decoded = try JSONDecoder().decode(SafeEnum<SourceType>.self, from: data)
        XCTAssertNil(decoded.value)
    }

    func testDecodesObjectValueAsNilWithoutThrowing() throws {
        let data = Data("{\"type\": \"autoteka\"}".utf8)
        let decoded = try JSONDecoder().decode(SafeEnum<SourceType>.self, from: data)
        XCTAssertNil(decoded.value)
    }

    func testDecodesNullValueAsNilWithoutThrowing() throws {
        let data = Data("null".utf8)
        let decoded = try JSONDecoder().decode(SafeEnum<SourceType>.self, from: data)
        XCTAssertNil(decoded.value)
    }

    func testDecodesNestedArrayValueAsNilWithoutThrowing() throws {
        let data = Data("[\"autoteka\"]".utf8)
        let decoded = try JSONDecoder().decode(SafeEnum<SourceType>.self, from: data)
        XCTAssertNil(decoded.value)
    }

    func testDecodesArrayWithNonStringValuesKeepingKnownOnes() throws {
        let data = Data("[\"autoteka\", 42, null, {\"a\": 1}, [true], \"sravni\"]".utf8)
        let decoded = try JSONDecoder().decode([SafeEnum<SourceType>].self, from: data)
        XCTAssertEqual(decoded.count, 6)
        XCTAssertEqual(decoded.compactMap { $0.value }, [.autoteka, .sravni])
    }
}
