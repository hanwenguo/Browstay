import Foundation

public struct WebURL: Equatable, Hashable, Sendable, CustomStringConvertible {
  public let url: URL

  public init?(_ url: URL) {
    guard
      let scheme = url.scheme?.lowercased(),
      scheme == "http" || scheme == "https",
      let host = url.host(percentEncoded: false),
      !host.isEmpty
    else {
      return nil
    }

    self.url = url
  }

  public var description: String {
    url.absoluteString
  }

  public static func validWebURLs(from urls: [URL]) -> [WebURL] {
    urls.compactMap(WebURL.init)
  }
}
