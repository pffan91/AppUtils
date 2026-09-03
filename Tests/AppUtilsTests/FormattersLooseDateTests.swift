import XCTest
@testable import AppUtils

/// `Formatters.date(fromLooseString:)` / `.dayMonthYear(fromLooseString:)`.
///
/// These exist because a single displayed field is often fed by more than one HTTP source, and the
/// sources disagree about how a date is written. Accepting only one shape shows a raw timestamp to
/// the user; guessing at an unknown shape shows a wrong date. So: parse every shape actually seen on
/// the wire, and hand back anything else untouched.
final class FormattersLooseDateTests: XCTestCase {

    // MARK: - Shapes that must be recognised

    func testISOWithTimeBecomesDayFirst() {
        XCTAssertEqual(Formatters.dayMonthYear(fromLooseString: "2026-01-31T00:00:00"), "31.01.2026")
    }

    func testISOWithMillisecondsBecomesDayFirst() {
        XCTAssertEqual(Formatters.dayMonthYear(fromLooseString: "2026-01-31T00:00:00.000"), "31.01.2026")
    }

    func testBareDayBecomesDayFirst() {
        XCTAssertEqual(Formatters.dayMonthYear(fromLooseString: "2026-07-30"), "30.07.2026")
    }

    /// A timezone-bearing value has to parse. The rendered day is deliberately not asserted: the
    /// output runs in the device timezone, so the calendar day of an instant differs between
    /// machines, and pinning it would make this suite flaky rather than strict.
    func testISOWithTimezoneIsParsed() {
        XCTAssertNotNil(Formatters.date(fromLooseString: "2026-01-31T12:00:00Z"))
    }

    /// The combination neither a plain `withInternetDateTime` formatter nor the timezone-less
    /// patterns accept — `.withFractionalSeconds` makes the fraction required, so it needs its own
    /// formatter.
    func testISOWithTimezoneAndFractionalSecondsIsParsed() {
        XCTAssertNotNil(Formatters.date(fromLooseString: "2026-01-31T12:00:00.000Z"))
    }

    func testSurroundingWhitespaceIsIgnored() {
        XCTAssertEqual(Formatters.dayMonthYear(fromLooseString: "  2026-01-31T00:00:00  "), "31.01.2026")
    }

    // MARK: - Idempotence

    /// The property that lets this sit on a field two sources write to: one sends ISO, the other the
    /// finished form, and normalising the finished one must change nothing.
    func testAlreadyDayFirstIsUnchanged() {
        XCTAssertEqual(Formatters.dayMonthYear(fromLooseString: "30.07.2026"), "30.07.2026")
    }

    /// The real guard for the case above — an already-formatted value must be *recognised*, not
    /// merely echoed, or a later change to the fallback would silently drop it.
    func testAlreadyDayFirstIsRecognised() {
        XCTAssertNotNil(Formatters.date(fromLooseString: "30.07.2026"))
    }

    // MARK: - Shapes that must not be guessed at

    func testUnrecognisedValueIsReturnedUntouched() {
        XCTAssertEqual(Formatters.dayMonthYear(fromLooseString: "не указано"), "не указано")
        XCTAssertNil(Formatters.date(fromLooseString: "не указано"))
    }

    func testEmptyValueStaysEmpty() {
        XCTAssertEqual(Formatters.dayMonthYear(fromLooseString: ""), "")
        XCTAssertNil(Formatters.date(fromLooseString: ""))
        XCTAssertNil(Formatters.date(fromLooseString: "   "))
    }

    // MARK: - The formatter itself

    /// POSIX locale, so the pattern does not follow the device's calendar or digit set.
    func testDayMonthYearFormatterIsFixedRegardlessOfDevice() {
        let reference = DateComponents(calendar: Calendar(identifier: .gregorian),
                                       timeZone: TimeZone(identifier: "UTC"),
                                       year: 2026, month: 1, day: 31, hour: 12).date!
        XCTAssertEqual(Formatters.dayMonthYearFormatter.string(from: reference).count, 10)
    }
}
