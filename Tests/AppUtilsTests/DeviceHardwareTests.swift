import XCTest
@testable import AppUtils

final class DeviceHardwareTests: XCTestCase {

    /// `uname` fills a fixed-size C buffer; a broken reduce would return "" or trailing NULs.
    func testIdentifierIsNonEmptyAndHasNoNul() {
        let identifier = DeviceHardware.identifier
        XCTAssertFalse(identifier.isEmpty)
        XCTAssertFalse(identifier.contains("\0"))
    }
}
