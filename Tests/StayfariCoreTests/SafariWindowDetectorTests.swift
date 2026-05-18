import CoreGraphics
import XCTest
@testable import StayfariCore

private struct StubWindowSnapshotProvider: WindowSnapshotProviding {
  let windows: [WindowInfo]

  func currentOnScreenWindows() -> [WindowInfo] {
    windows
  }
}

final class SafariWindowDetectorTests: XCTestCase {
  func testFindsNormalVisibleSafariWindowByBundleIdentifier() async {
    let detector = SafariWindowDetector(snapshotProvider: StubWindowSnapshotProvider(windows: [
      WindowInfo(ownerName: "Safari", bundleIdentifier: "com.apple.Safari", processIdentifier: 42, layer: 0, alpha: 1, bounds: CGRect(x: 10, y: 10, width: 1200, height: 800), name: "Example", isOnscreen: true)
    ]))

    let result = await detector.hasVisibleSafariWindow()

    XCTAssertTrue(result)
  }

  func testFindsNormalVisibleSafariWindowByOwnerNameWhenBundleIdentifierIsUnavailable() async {
    let detector = SafariWindowDetector(snapshotProvider: StubWindowSnapshotProvider(windows: [
      WindowInfo(ownerName: "Safari", bundleIdentifier: nil, processIdentifier: 42, layer: 0, alpha: 1, bounds: CGRect(x: 10, y: 10, width: 1200, height: 800), name: "Example", isOnscreen: true)
    ]))

    let result = await detector.hasVisibleSafariWindow()

    XCTAssertTrue(result)
  }

  func testRejectsNonSafariAndNonNormalWindows() async {
    let detector = SafariWindowDetector(snapshotProvider: StubWindowSnapshotProvider(windows: [
      WindowInfo(ownerName: "Finder", bundleIdentifier: "com.apple.finder", processIdentifier: 10, layer: 0, alpha: 1, bounds: CGRect(x: 0, y: 0, width: 900, height: 700), name: "Finder", isOnscreen: true),
      WindowInfo(ownerName: "Safari", bundleIdentifier: "com.apple.Safari", processIdentifier: 11, layer: 25, alpha: 1, bounds: CGRect(x: 0, y: 0, width: 900, height: 700), name: "Menu", isOnscreen: true),
      WindowInfo(ownerName: "Safari", bundleIdentifier: "com.apple.Safari", processIdentifier: 12, layer: 0, alpha: 0, bounds: CGRect(x: 0, y: 0, width: 900, height: 700), name: "Transparent", isOnscreen: true),
      WindowInfo(ownerName: "Safari", bundleIdentifier: "com.apple.Safari", processIdentifier: 13, layer: 0, alpha: 1, bounds: CGRect(x: 0, y: 0, width: 40, height: 40), name: "Tiny", isOnscreen: true)
    ]))

    let result = await detector.hasVisibleSafariWindow()

    XCTAssertFalse(result)
  }

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
