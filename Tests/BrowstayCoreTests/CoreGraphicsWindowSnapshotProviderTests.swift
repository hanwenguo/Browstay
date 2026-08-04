import CoreGraphics
import XCTest
@testable import BrowstayCore

final class CoreGraphicsWindowSnapshotProviderTests: XCTestCase {
  func testParsesValidCoreGraphicsWindowDictionary() {
    let bounds = CGRect(x: 10, y: 20, width: 1200, height: 800)

    let result = CoreGraphicsWindowSnapshotProvider.windowInfo(from: [
      kCGWindowOwnerName as String: "Safari",
      kCGWindowLayer as String: 0,
      kCGWindowBounds as String: bounds.dictionaryRepresentation as Any,
      kCGWindowAlpha as String: NSNumber(value: 0.75),
      kCGWindowName as String: "Example",
      kCGWindowIsOnscreen as String: NSNumber(value: true),
      kCGWindowOwnerPID as String: NSNumber(value: 12345)
    ])

    XCTAssertEqual(result?.ownerName, "Safari")
    XCTAssertEqual(result?.layer, 0)
    XCTAssertEqual(result?.alpha, 0.75)
    XCTAssertEqual(result?.bounds, bounds)
    XCTAssertEqual(result?.name, "Example")
    XCTAssertEqual(result?.isOnscreen, true)
    XCTAssertEqual(result?.processIdentifier, 12345)
  }

  func testMissingRequiredCoreGraphicsWindowFieldsReturnNil() {
    let bounds = CGRect(x: 0, y: 0, width: 900, height: 700)
    let validDictionary: [String: Any] = [
      kCGWindowOwnerName as String: "Safari",
      kCGWindowLayer as String: 0,
      kCGWindowBounds as String: bounds.dictionaryRepresentation as Any
    ]

    XCTAssertNil(CoreGraphicsWindowSnapshotProvider.windowInfo(from: validDictionary.removingValue(forKey: kCGWindowOwnerName as String)))
    XCTAssertNil(CoreGraphicsWindowSnapshotProvider.windowInfo(from: validDictionary.removingValue(forKey: kCGWindowLayer as String)))
    XCTAssertNil(CoreGraphicsWindowSnapshotProvider.windowInfo(from: validDictionary.removingValue(forKey: kCGWindowBounds as String)))
  }

  func testInvalidCoreGraphicsBoundsDictionaryReturnsNil() {
    let result = CoreGraphicsWindowSnapshotProvider.windowInfo(from: [
      kCGWindowOwnerName as String: "Safari",
      kCGWindowLayer as String: 0,
      kCGWindowBounds as String: ["Invalid": 1] as NSDictionary
    ])

    XCTAssertNil(result)
  }

  func testMissingOptionalCoreGraphicsWindowFieldsUseDefaults() {
    let bounds = CGRect(x: 0, y: 0, width: 900, height: 700)

    let result = CoreGraphicsWindowSnapshotProvider.windowInfo(from: [
      kCGWindowOwnerName as String: "Safari",
      kCGWindowLayer as String: 0,
      kCGWindowBounds as String: bounds.dictionaryRepresentation as Any
    ])

    XCTAssertEqual(result?.alpha, 1)
    XCTAssertNil(result?.name)
    XCTAssertEqual(result?.isOnscreen, true)
    XCTAssertNil(result?.processIdentifier)
  }

  func testCoreGraphicsOnscreenFalseIsPreserved() {
    let bounds = CGRect(x: 0, y: 0, width: 900, height: 700)

    let result = CoreGraphicsWindowSnapshotProvider.windowInfo(from: [
      kCGWindowOwnerName as String: "Safari",
      kCGWindowLayer as String: 0,
      kCGWindowBounds as String: bounds.dictionaryRepresentation as Any,
      kCGWindowIsOnscreen as String: NSNumber(value: false)
    ])

    XCTAssertEqual(result?.isOnscreen, false)
  }
}

private extension Dictionary where Key == String, Value == Any {
  func removingValue(forKey key: String) -> [String: Any] {
    var copy = self
    copy.removeValue(forKey: key)
    return copy
  }
}
