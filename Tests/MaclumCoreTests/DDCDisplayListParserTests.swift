import XCTest
@testable import MaclumCore

final class DDCDisplayListParserTests: XCTestCase {
    func testParsesM1DDCBracketedDisplayRowsAndIgnoresUnnamedBuiltInDisplay() {
        let output = """
        [1] (null) (37D8832A-2D66-02CA-B9F7-8F30A301B230)
        [2] DELL U2725QE (287C65F4-3027-4BFD-9FD9-056FF307AFFA)
        """

        XCTAssertEqual(
            DDCDisplayListParser.parse(output),
            [DDCDisplay(id: "287C65F4-3027-4BFD-9FD9-056FF307AFFA", name: "DELL U2725QE")]
        )
    }

    func testParsesAReportedDDCLuminance() {
        XCTAssertEqual(DDCLuminanceParser.parse("0"), 0)
        XCTAssertEqual(DDCLuminanceParser.parse("97\n"), 97)
        XCTAssertEqual(DDCLuminanceParser.parse("100"), 100)
    }

    func testRejectsInvalidDDCLuminanceOutput() {
        XCTAssertNil(DDCLuminanceParser.parse("not a number"))
        XCTAssertNil(DDCLuminanceParser.parse("-1"))
        XCTAssertNil(DDCLuminanceParser.parse("101"))
        XCTAssertNil(DDCLuminanceParser.parse("97 extra"))
        XCTAssertNil(DDCLuminanceParser.parse("97\n98"))
        XCTAssertNil(DDCLuminanceParser.parse("97\nwarning"))
    }
}
