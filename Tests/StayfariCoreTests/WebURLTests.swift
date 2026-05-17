import XCTest
@testable import StayfariCore

final class WebURLTests: XCTestCase {
  func testAcceptsHTTPAndHTTPSWithHosts() throws {
    let http = try XCTUnwrap(WebURL(URL(string: "http://example.com/path")!))
    let https = try XCTUnwrap(WebURL(URL(string: "HTTPS://Example.com/search?q=stayfari")!))

    XCTAssertEqual(http.url.absoluteString, "http://example.com/path")
    XCTAssertEqual(https.url.scheme?.lowercased(), "https")
  }

  func testRejectsNonWebSchemesAndMissingHosts() {
    XCTAssertNil(WebURL(URL(string: "mailto:hello@example.com")!))
    XCTAssertNil(WebURL(URL(string: "file:///tmp/index.html")!))
    XCTAssertNil(WebURL(URL(string: "stayfari://open")!))
    XCTAssertNil(WebURL(URL(string: "https:/broken")!))
  }

  func testFiltersMixedIncomingURLsInOrder() {
    let urls = [
      URL(string: "mailto:hello@example.com")!,
      URL(string: "https://apple.com")!,
      URL(string: "http://localhost:8080/path")!,
      URL(string: "file:///tmp/readme.txt")!
    ]

    let filtered = WebURL.validWebURLs(from: urls).map(\.url.absoluteString)

    XCTAssertEqual(filtered, [
      "https://apple.com",
      "http://localhost:8080/path"
    ])
  }
}
