import CoreGraphics

public struct WindowInfo: Equatable, Sendable {
  public let ownerName: String
  public let bundleIdentifier: String?
  public let processIdentifier: pid_t?
  public let layer: Int
  public let alpha: Double
  public let bounds: CGRect
  public let name: String?
  public let isOnscreen: Bool

  public init(
    ownerName: String,
    bundleIdentifier: String?,
    processIdentifier: pid_t?,
    layer: Int,
    alpha: Double,
    bounds: CGRect,
    name: String?,
    isOnscreen: Bool
  ) {
    self.ownerName = ownerName
    self.bundleIdentifier = bundleIdentifier
    self.processIdentifier = processIdentifier
    self.layer = layer
    self.alpha = alpha
    self.bounds = bounds
    self.name = name
    self.isOnscreen = isOnscreen
  }
}
