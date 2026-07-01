import XCTest
@testable import BrowstayCore

final class BrowstayCoreTests: XCTestCase {
  func testVersionConstants() {
    XCTAssertEqual(BrowstayVersion.appName, "Browstay")
    XCTAssertEqual(BrowstayVersion.bundleIdentifier, "io.hanwen.Browstay")
  }
}
