import Foundation
import XCTest
@testable import StayfariCore

private struct StubBrowserApplicationLocator: BrowserApplicationLocating {
  let applicationURLs: [String: URL]

  func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL? {
    applicationURLs[bundleIdentifier]
  }
}

final class BrowserCatalogTests: XCTestCase {
  func testCuratedDefinitionsUseValidatedBrowserMetadata() {
    XCTAssertEqual(BrowserDefinition.supported, [
      BrowserDefinition(
        id: .safari,
        displayName: "Safari",
        bundleIdentifier: "com.apple.Safari",
        ownerNames: ["Safari"],
        newWindowStrategy: .safariDocument
      ),
      BrowserDefinition(
        id: .orion,
        displayName: "Orion",
        bundleIdentifier: "com.kagi.kagimacOS",
        ownerNames: ["Orion"],
        newWindowStrategy: .orionDocument
      ),
      BrowserDefinition(
        id: .helium,
        displayName: "Helium",
        bundleIdentifier: "net.imput.helium",
        ownerNames: ["Helium"],
        newWindowStrategy: .chromiumWindow
      )
    ])
  }

  func testInstalledBrowsersContainOnlyDefinitionsResolvedByWorkspace() {
    let safariURL = URL(fileURLWithPath: "/System/Applications/Safari.app")
    let heliumURL = URL(fileURLWithPath: "/Applications/Helium.app")
    let catalog = BrowserCatalog(applicationLocator: StubBrowserApplicationLocator(applicationURLs: [
      BrowserDefinition.safari.bundleIdentifier: safariURL,
      BrowserDefinition.helium.bundleIdentifier: heliumURL
    ]))

    let installations = catalog.installedBrowsers()

    XCTAssertEqual(installations, [
      BrowserInstallation(definition: .safari, applicationURL: safariURL),
      BrowserInstallation(definition: .helium, applicationURL: heliumURL)
    ])
  }

  func testInstallationReturnsNilForUnavailableSupportedBrowser() {
    let catalog = BrowserCatalog(applicationLocator: StubBrowserApplicationLocator(applicationURLs: [:]))

    XCTAssertNil(catalog.installation(for: .orion))
  }
}
