import Foundation

public enum BrowserID: String, CaseIterable, Codable, Sendable {
  case safari
  case orion
  case helium
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

  public static let supported: [BrowserDefinition] = [
    .safari,
    .orion,
    .helium
  ]

  public static func definition(for id: BrowserID) -> BrowserDefinition {
    supported.first { $0.id == id } ?? .safari
  }

  public static func definition(bundleIdentifier: String) -> BrowserDefinition? {
    supported.first { $0.bundleIdentifier == bundleIdentifier }
  }
}
