import Foundation

public enum BrowserID: String, CaseIterable, Codable, Sendable {
  case safari
  case orion
  case helium
  case chrome
  case chromium
  case ungoogledChromium
}

public enum BrowserNewWindowStrategy: String, Sendable {
  case safariDocument
  case orionDocument
  case chromiumWindow
}

public struct BrowserDefinition: Identifiable, Equatable, Sendable {
  public let id: BrowserID
  public let displayName: String
  public let bundleIdentifier: String
  public let ownerNames: [String]
  public let newWindowStrategy: BrowserNewWindowStrategy

  public init(
    id: BrowserID,
    displayName: String,
    bundleIdentifier: String,
    ownerNames: [String],
    newWindowStrategy: BrowserNewWindowStrategy
  ) {
    self.id = id
    self.displayName = displayName
    self.bundleIdentifier = bundleIdentifier
    self.ownerNames = ownerNames
    self.newWindowStrategy = newWindowStrategy
  }

  public static let safari = BrowserDefinition(
    id: .safari,
    displayName: "Safari",
    bundleIdentifier: "com.apple.Safari",
    ownerNames: ["Safari"],
    newWindowStrategy: .safariDocument
  )

  public static let orion = BrowserDefinition(
    id: .orion,
    displayName: "Orion",
    bundleIdentifier: "com.kagi.kagimacOS",
    ownerNames: ["Orion"],
    newWindowStrategy: .orionDocument
  )

  public static let helium = BrowserDefinition(
    id: .helium,
    displayName: "Helium",
    bundleIdentifier: "net.imput.helium",
    ownerNames: ["Helium"],
    newWindowStrategy: .chromiumWindow
  )

  public static let chrome = BrowserDefinition(
    id: .chrome,
    displayName: "Google Chrome",
    bundleIdentifier: "com.google.Chrome",
    ownerNames: ["Google Chrome"],
    newWindowStrategy: .chromiumWindow
  )

  public static let chromium = BrowserDefinition(
    id: .chromium,
    displayName: "Chromium",
    bundleIdentifier: "org.chromium.Chromium",
    ownerNames: ["Chromium"],
    newWindowStrategy: .chromiumWindow
  )

  /// Installs as `Chromium.app` but has its own bundle identifier, so it needs
  /// a definition separate from upstream Chromium.
  public static let ungoogledChromium = BrowserDefinition(
    id: .ungoogledChromium,
    displayName: "Ungoogled Chromium",
    bundleIdentifier: "io.ungoogled-software.ungoogled-chromium",
    ownerNames: ["Chromium"],
    newWindowStrategy: .chromiumWindow
  )

  public static let supported: [BrowserDefinition] = [
    .safari,
    .orion,
    .helium,
    .chrome,
    .chromium,
    .ungoogledChromium
  ]

  public static func definition(for id: BrowserID) -> BrowserDefinition {
    supported.first { $0.id == id } ?? .safari
  }

  public static func definition(bundleIdentifier: String) -> BrowserDefinition? {
    supported.first { $0.bundleIdentifier == bundleIdentifier }
  }
}
