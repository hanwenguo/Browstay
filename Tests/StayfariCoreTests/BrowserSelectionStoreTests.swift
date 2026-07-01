import XCTest
@testable import StayfariCore

private final class MemoryBrowserSelectionDefaults: BrowserSelectionDefaults {
  var values: [String: String] = [:]

  func string(forKey defaultName: String) -> String? {
    values[defaultName]
  }

  func set(_ value: String, forKey defaultName: String) {
    values[defaultName] = value
  }
}

final class BrowserSelectionStoreTests: XCTestCase {
  func testPersistedSelectionWinsEvenWhenBrowserIsUnavailable() {
    let defaults = MemoryBrowserSelectionDefaults()
    defaults.values[BrowserSelectionStore.selectionKey] = BrowserID.orion.rawValue
    let store = BrowserSelectionStore(defaults: defaults)

    XCTAssertEqual(store.selectedBrowser(currentHTTPSHandler: "com.apple.Safari"), .orion)
  }

  func testFirstRunUsesSupportedCurrentHTTPSHandler() {
    let store = BrowserSelectionStore(defaults: MemoryBrowserSelectionDefaults())

    XCTAssertEqual(store.selectedBrowser(currentHTTPSHandler: "net.imput.helium"), .helium)
  }

  func testFirstRunMapsOldStayfariHandlerToSafari() {
    let store = BrowserSelectionStore(defaults: MemoryBrowserSelectionDefaults())

    XCTAssertEqual(store.selectedBrowser(currentHTTPSHandler: "com.hanwen.Stayfari"), .safari)
  }

  func testFirstRunFallsBackToSafariForUnsupportedHandler() {
    let store = BrowserSelectionStore(defaults: MemoryBrowserSelectionDefaults())

    XCTAssertEqual(store.selectedBrowser(currentHTTPSHandler: "org.mozilla.firefox"), .safari)
  }

  func testSetSelectedBrowserPersistsStableIdentifier() {
    let defaults = MemoryBrowserSelectionDefaults()
    let store = BrowserSelectionStore(defaults: defaults)

    store.setSelectedBrowser(.helium)

    XCTAssertEqual(defaults.values[BrowserSelectionStore.selectionKey], "helium")
  }
}
