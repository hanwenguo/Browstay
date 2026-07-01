import CoreGraphics
import XCTest
@testable import BrowstayCore

private struct BrowserWindowStubSnapshotProvider: WindowSnapshotProviding {
  let windows: [WindowInfo]

  func currentOnScreenWindows() -> [WindowInfo] {
    windows
  }
}

final class BrowserWindowDetectorTests: XCTestCase {
  func testMatchesSelectedBrowserByBundleIdentifier() async {
    let detector = BrowserWindowDetector(snapshotProvider: BrowserWindowStubSnapshotProvider(windows: [
      window(ownerName: "Orion", bundleIdentifier: BrowserDefinition.orion.bundleIdentifier)
    ]))

    let hasOrionWindow = await detector.hasVisibleWindow(for: .orion)
    let hasSafariWindow = await detector.hasVisibleWindow(for: .safari)

    XCTAssertTrue(hasOrionWindow)
    XCTAssertFalse(hasSafariWindow)
  }

  func testUsesOwnerNameOnlyWhenBundleIdentifierIsUnavailable() async {
    let detector = BrowserWindowDetector(snapshotProvider: BrowserWindowStubSnapshotProvider(windows: [
      window(ownerName: "Helium", bundleIdentifier: nil),
      window(ownerName: "Safari", bundleIdentifier: "com.example.NotSafari")
    ]))

    let hasHeliumWindow = await detector.hasVisibleWindow(for: .helium)
    let hasSafariWindow = await detector.hasVisibleWindow(for: .safari)

    XCTAssertTrue(hasHeliumWindow)
    XCTAssertFalse(hasSafariWindow)
  }

  func testRejectsNonNormalTargetWindows() async {
    let detector = BrowserWindowDetector(snapshotProvider: BrowserWindowStubSnapshotProvider(windows: [
      window(ownerName: "Safari", bundleIdentifier: "com.apple.Safari", layer: 25),
      window(ownerName: "Safari", bundleIdentifier: "com.apple.Safari", alpha: 0),
      window(
        ownerName: "Safari",
        bundleIdentifier: "com.apple.Safari",
        bounds: CGRect(x: 0, y: 0, width: 40, height: 40)
      ),
      window(ownerName: "Safari", bundleIdentifier: "com.apple.Safari", isOnscreen: false)
    ]))

    let hasSafariWindow = await detector.hasVisibleWindow(for: .safari)

    XCTAssertFalse(hasSafariWindow)
  }

  private func window(
    ownerName: String,
    bundleIdentifier: String?,
    layer: Int = 0,
    alpha: Double = 1,
    bounds: CGRect = CGRect(x: 0, y: 0, width: 900, height: 700),
    isOnscreen: Bool = true
  ) -> WindowInfo {
    WindowInfo(
      ownerName: ownerName,
      bundleIdentifier: bundleIdentifier,
      processIdentifier: 10,
      layer: layer,
      alpha: alpha,
      bounds: bounds,
      name: "Browser",
      isOnscreen: isOnscreen
    )
  }
}
