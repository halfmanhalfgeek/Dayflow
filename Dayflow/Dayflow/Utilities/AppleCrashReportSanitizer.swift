import Foundation

enum AppleCrashReportSanitizer {
  private static let scalarKeys: Set<String> = [
    "app_name",
    "bundleID",
    "bug_type",
    "build_version",
    "incident_id",
    "os_version",
    "product",
    "timestamp",
  ]

  private static let exceptionKeys: Set<String> = [
    "codes",
    "signal",
    "subtype",
    "type",
  ]

  private static let terminationKeys: Set<String> = [
    "code",
    "indicator",
    "namespace",
  ]

  static func sanitize(data: Data) -> Data? {
    guard let report = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }

    var sanitized = scalarValues(from: report, allowedKeys: scalarKeys)
    if let exception = report["exception"] as? [String: Any] {
      sanitized["exception"] = scalarValues(from: exception, allowedKeys: exceptionKeys)
    }
    if let termination = report["termination"] as? [String: Any] {
      sanitized["termination"] = scalarValues(from: termination, allowedKeys: terminationKeys)
    }

    guard !sanitized.isEmpty else { return nil }
    return try? JSONSerialization.data(withJSONObject: sanitized, options: [.sortedKeys])
  }

  private static func scalarValues(
    from dictionary: [String: Any],
    allowedKeys: Set<String>
  ) -> [String: Any] {
    dictionary.reduce(into: [String: Any]()) { result, entry in
      guard allowedKeys.contains(entry.key), isJSONScalar(entry.value) else { return }
      result[entry.key] = entry.value
    }
  }

  private static func isJSONScalar(_ value: Any) -> Bool {
    value is String || value is NSNumber || value is NSNull
  }
}