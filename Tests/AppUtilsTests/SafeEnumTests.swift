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
}
