import XCTest
@testable import StayfariCore

final class StayfariCoreTests: XCTestCase {
  func testVersionConstants() {
    XCTAssertEqual(StayfariVersion.appName, "Stayfari")
    XCTAssertEqual(StayfariVersion.bundleIdentifier, "com.hanwen.Stayfari")
    XCTAssertEqual(StayfariVersion.safariBundleIdentifier, "com.apple.Safari")
    XCTAssertEqual(StayfariVersion.safariOwnerName, "Safari")
  }
}
