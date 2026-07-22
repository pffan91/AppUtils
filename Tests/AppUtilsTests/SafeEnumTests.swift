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

    // MARK: - Equatable / Hashable

    private func decodeOne(_ json: String) throws -> SafeEnum<SourceType> {
        try JSONDecoder().decode(SafeEnum<SourceType>.self, from: Data(json.utf8))
    }

    func testEqualForSameKnownValue() throws {
        let a = try decodeOne("\"autoteka\"")
        let b = try decodeOne("\"autoteka\"")
        XCTAssertEqual(a, b)
    }

    func testNotEqualForDifferentValues() throws {
        let a = try decodeOne("\"autoteka\"")
        let b = try decodeOne("\"sravni\"")
        XCTAssertNotEqual(a, b)
        let c = try decodeOne("\"unknown_source\"")
        XCTAssertNotEqual(a, c)
    }

    func testNilValuesAreEqualRegardlessOfOriginalRawValue() throws {
        // Both decode to value == nil, so they compare equal even though
        // the original raw strings differ - the raw value is not stored.
        let a = try decodeOne("\"unknown_one\"")
        let b = try decodeOne("\"unknown_two\"")
        XCTAssertEqual(a, b)
    }

    func testHashableWorksAsDictionaryKeyAndSetElement() throws {
        let a = try decodeOne("\"autoteka\"")
        let b = try decodeOne("\"autoteka\"")
        let c = try decodeOne("\"sravni\"")
        XCTAssertEqual(a.hashValue, b.hashValue)

        var finished: [SafeEnum<SourceType>: Bool] = [:]
        finished[a] = true
        XCTAssertEqual(finished[b], true)
        XCTAssertNil(finished[c])

        let set: Set<SafeEnum<SourceType>> = [a, b, c]
        XCTAssertEqual(set.count, 2)
    }
}
