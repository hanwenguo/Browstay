import CoreServices
import XCTest
@testable import StayfariCore

private final class FakeLaunchServicesClient: LaunchServicesClient {
  var handlers: [String: String?] = [
    "http": "com.apple.Safari",
    "https": "com.apple.Safari"
  ]
  var setCalls: [(scheme: String, handler: String)] = []
  var statusToReturn: OSStatus = noErr

  func copyDefaultHandler(for scheme: String) -> String? {
    handlers[scheme] ?? nil
  }

  func setDefaultHandler(_ handler: String, for scheme: String) -> OSStatus {
    setCalls.append((scheme: scheme, handler: handler))
    handlers[scheme] = handler
    return statusToReturn
  }
}

final class DefaultBrowserManagerTests: XCTestCase {
  func testReadsHTTPAndHTTPSStatus() {
    let client = FakeLaunchServicesClient()
    let manager = DefaultBrowserManager(ownBundleIdentifier: "com.hanwen.Stayfari", launchServicesClient: client)

    let status = manager.status()

    XCTAssertEqual(status.map(\.scheme), [.http, .https])
    XCTAssertEqual(status.map(\.currentHandler), ["com.apple.Safari", "com.apple.Safari"])
    XCTAssertEqual(status.map(\.isStayfari), [false, false])
  }

  func testSetsStayfariForBothSchemes() {
    let client = FakeLaunchServicesClient()
    let manager = DefaultBrowserManager(ownBundleIdentifier: "com.hanwen.Stayfari", launchServicesClient: client)

    let results = manager.setStayfariAsDefault()

    XCTAssertEqual(client.setCalls.map(\.scheme), ["http", "https"])
    XCTAssertEqual(client.setCalls.map(\.handler), ["com.hanwen.Stayfari", "com.hanwen.Stayfari"])
    XCTAssertEqual(results.map(\.succeeded), [true, true])
  }

  func testRestoresSafariForBothSchemes() {
    let client = FakeLaunchServicesClient()
    let manager = DefaultBrowserManager(ownBundleIdentifier: "com.hanwen.Stayfari", launchServicesClient: client)

    let results = manager.restoreSafariAsDefault()

    XCTAssertEqual(client.setCalls.map(\.handler), ["com.apple.Safari", "com.apple.Safari"])
    XCTAssertEqual(results.map(\.scheme), [.http, .https])
  }
}
