import XCTest

@testable import Dayflow

final class DailyBriefLinkImagesTests: XCTestCase {
  func testAllowsPublicWebURLsOnStandardPorts() {
    XCTAssertTrue(DailyBriefLinkImages.isAllowedRemoteURL(URL(string: "https://example.com/image.jpg")!))
    XCTAssertTrue(DailyBriefLinkImages.isAllowedRemoteURL(URL(string: "http://example.com:80/page")!))
  }

  func testRejectsNonWebSchemesAndCredentials() {
    XCTAssertFalse(DailyBriefLinkImages.isAllowedRemoteURL(URL(string: "file:///etc/passwd")!))
    XCTAssertFalse(DailyBriefLinkImages.isAllowedRemoteURL(URL(string: "https://user:pass@example.com")!))
    XCTAssertFalse(DailyBriefLinkImages.isAllowedRemoteURL(URL(string: "https://example.com:8443")!))
  }

  func testRejectsLocalHostsAndIPAddresses() {
    for value in [
      "http://localhost",
      "http://printer.local/image.jpg",
      "http://127.0.0.1/image.jpg",
      "http://10.0.0.8/image.jpg",
      "http://[::1]/image.jpg",
    ] {
      XCTAssertFalse(DailyBriefLinkImages.isAllowedRemoteURL(URL(string: value)!))
    }
  }
}