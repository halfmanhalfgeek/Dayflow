import Foundation
import XCTest

@testable import Dayflow

final class AppleCrashReportSanitizerTests: XCTestCase {
  func testSanitizeKeepsAllowlistedMetadataAndDropsSensitiveFields() throws {
    let data = Data(
      """
      {
        "app_name": "Dayflow",
        "bug_type": 309,
        "os_version": "macOS 26.5",
        "timestamp": "2026-09-04 12:00:00.00 +0000",
        "exception": {
          "type": "EXC_CRASH",
          "signal": "SIGABRT",
          "codes": "0x0",
          "message": "/Users/private/secret.txt"
        },
        "termination": {"namespace": "SIGNAL", "code": 6},
        "user": "private-user",
        "path": "/Users/private/Dayflow.app",
        "threads": [{"frames": ["private frame"]}]
      }
      """.utf8)

    let sanitized = try XCTUnwrap(AppleCrashReportSanitizer.sanitize(data: data))
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: sanitized) as? [String: Any])

    XCTAssertEqual(object["app_name"] as? String, "Dayflow")
    XCTAssertEqual(object["bug_type"] as? Int, 309)
    XCTAssertEqual((object["exception"] as? [String: Any])?["type"] as? String, "EXC_CRASH")
    XCTAssertNil(object["user"])
    XCTAssertNil(object["path"])
    XCTAssertNil(object["threads"])
    XCTAssertNil((object["exception"] as? [String: Any])?["message"])
  }

  func testSanitizeRejectsReportsWithoutAllowlistedFields() {
    let data = Data("{\"threads\": [], \"path\": \"/Users/private\"}".utf8)

    XCTAssertNil(AppleCrashReportSanitizer.sanitize(data: data))
  }
}