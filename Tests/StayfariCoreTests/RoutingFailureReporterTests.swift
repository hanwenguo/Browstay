import XCTest
@testable import StayfariCore

@MainActor
private final class RecordingNotificationClient: BrowstayNotificationClient {
  var authorizationRequests = 0
  var notifications: [(title: String, body: String)] = []

  func requestAuthorization() async {
    authorizationRequests += 1
  }

  func post(title: String, body: String) async {
    notifications.append((title: title, body: body))
  }
}

final class RoutingFailureReporterTests: XCTestCase {
  @MainActor
  func testRequestsNotificationAuthorization() async {
    let client = RecordingNotificationClient()
    let reporter = RoutingFailureReporter(notificationClient: client)

    await reporter.requestAuthorization()

    XCTAssertEqual(client.authorizationRequests, 1)
  }

  @MainActor
  func testUnavailableBrowserPostsFailureWithoutURL() async {
    let client = RecordingNotificationClient()
    let reporter = RoutingFailureReporter(notificationClient: client)
    let privateURL = URL(string: "https://private.example/secret")!

    await reporter.report(URLRoutingSummary(actions: [
      .browserUnavailable(privateURL, browser: .orion)
    ]))

    XCTAssertEqual(client.notifications.map(\.title), ["Orion is unavailable"])
    XCTAssertEqual(client.notifications.map(\.body), [
      "Browstay could not open 1 link because Orion is not installed."
    ])
    XCTAssertFalse(client.notifications[0].body.contains(privateURL.absoluteString))
  }

  @MainActor
  func testAutomationFallbackPostsWarningForSameBrowser() async {
    let client = RecordingNotificationClient()
    let reporter = RoutingFailureReporter(notificationClient: client)

    await reporter.report(URLRoutingSummary(actions: [
      .fellBackToNormal(
        URL(string: "https://example.com")!,
        browser: .helium,
        reason: "Denied"
      )
    ]))

    XCTAssertEqual(client.notifications.map(\.title), ["Opened normally in Helium"])
    XCTAssertEqual(client.notifications.map(\.body), [
      "Current-Space automation failed; Helium used its normal link behavior."
    ])
  }

  @MainActor
  func testCleanRouteDoesNotPostNotification() async {
    let client = RecordingNotificationClient()
    let reporter = RoutingFailureReporter(notificationClient: client)

    await reporter.report(URLRoutingSummary(actions: [
      .openedNormally(URL(string: "https://example.com")!, browser: .safari)
    ]))

    XCTAssertEqual(client.notifications.count, 0)
  }
}
