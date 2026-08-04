import CoreServices
import XCTest
@testable import BrowstayCore

private final class FakeLaunchServicesClient: LaunchServicesClient {
  var handlers: [String: String?] = [
    "http": "com.apple.Safari",
    "https": "com.apple.Safari"
  ]
  var setCalls: [(scheme: String, handler: String)] = []
  var statusesByScheme: [String: OSStatus] = [:]

  func copyDefaultHandler(for scheme: String) -> String? {
    handlers[scheme] ?? nil
  }

  func setDefaultHandler(_ handler: String, for scheme: String) -> OSStatus {
    setCalls.append((scheme: scheme, handler: handler))
    let status = statusesByScheme[scheme] ?? noErr
    if status == noErr {
      handlers[scheme] = handler
    }
    return status
  }
}

final class DefaultBrowserManagerTests: XCTestCase {
  func testReadsHTTPAndHTTPSStatus() {
    let client = FakeLaunchServicesClient()
    let manager = DefaultBrowserManager(ownBundleIdentifier: "io.hanwen.Browstay", launchServicesClient: client)

    let status = manager.status()

    XCTAssertEqual(status.map(\.scheme), [.http, .https])
    XCTAssertEqual(status.map(\.currentHandler), ["com.apple.Safari", "com.apple.Safari"])
    XCTAssertEqual(status.map(\.isBrowstay), [false, false])
  }

  func testSetsBrowstayForBothSchemes() {
    let client = FakeLaunchServicesClient()
    let manager = DefaultBrowserManager(ownBundleIdentifier: "io.hanwen.Browstay", launchServicesClient: client)

    let results = manager.setBrowstayAsDefault()

    XCTAssertEqual(client.setCalls.map(\.scheme), ["http", "https"])
    XCTAssertEqual(client.setCalls.map(\.handler), ["io.hanwen.Browstay", "io.hanwen.Browstay"])
    XCTAssertEqual(results.map(\.succeeded), [true, true])
  }

  func testSettingBrowstayReportsPartialFailuresAndKeepsFailedHandlerUnchanged() {
    let client = FakeLaunchServicesClient()
    let failureStatus: OSStatus = -10814
    client.statusesByScheme = [
      "http": noErr,
      "https": failureStatus
    ]
    let manager = DefaultBrowserManager(ownBundleIdentifier: "io.hanwen.Browstay", launchServicesClient: client)

    let results = manager.setBrowstayAsDefault()

    XCTAssertEqual(client.setCalls.map(\.scheme), ["http", "https"])
    XCTAssertEqual(client.setCalls.map(\.handler), ["io.hanwen.Browstay", "io.hanwen.Browstay"])
    XCTAssertEqual(results.map(\.scheme), [.http, .https])
    XCTAssertEqual(results.map(\.status), [noErr, failureStatus])
    XCTAssertEqual(results.map(\.succeeded), [true, false])
    XCTAssertEqual(client.handlers["http"]!, "io.hanwen.Browstay")
    XCTAssertEqual(client.handlers["https"]!, "com.apple.Safari")
  }

  func testRestoresSelectedBrowserForBothSchemes() {
    let client = FakeLaunchServicesClient()
    let manager = DefaultBrowserManager(ownBundleIdentifier: "io.hanwen.Browstay", launchServicesClient: client)

    let results = manager.restoreDefault(to: .orion)

    XCTAssertEqual(client.setCalls.map(\.handler), ["com.kagi.kagimacOS", "com.kagi.kagimacOS"])
    XCTAssertEqual(results.map(\.scheme), [.http, .https])
  }
}
