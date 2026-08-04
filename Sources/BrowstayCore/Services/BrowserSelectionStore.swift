import Foundation

public protocol BrowserSelectionDefaults: AnyObject {
  func string(forKey defaultName: String) -> String?
  func set(_ value: String, forKey defaultName: String)
}

public final class UserDefaultsBrowserSelectionDefaults: BrowserSelectionDefaults {
  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func string(forKey defaultName: String) -> String? {
    defaults.string(forKey: defaultName)
  }

  public func set(_ value: String, forKey defaultName: String) {
    defaults.set(value, forKey: defaultName)
  }
}

public final class BrowserSelectionStore {
  public static let selectionKey = "selectedBrowserID"
  private static let legacyStayfariBundleIdentifier = "com.hanwen.Stayfari"

  private let defaults: BrowserSelectionDefaults

  public init(defaults: BrowserSelectionDefaults = UserDefaultsBrowserSelectionDefaults()) {
    self.defaults = defaults
  }

  public func selectedBrowser(currentHTTPSHandler: String?) -> BrowserID {
    if
      let rawValue = defaults.string(forKey: Self.selectionKey),
      let browserID = BrowserID(rawValue: rawValue)
    {
      return browserID
    }

    if currentHTTPSHandler == Self.legacyStayfariBundleIdentifier {
      return .safari
    }

    if
      let currentHTTPSHandler,
      let browser = BrowserDefinition.definition(bundleIdentifier: currentHTTPSHandler)
    {
      return browser.id
    }

    return .safari
  }

  public func setSelectedBrowser(_ browserID: BrowserID) {
    defaults.set(browserID.rawValue, forKey: Self.selectionKey)
  }
}
