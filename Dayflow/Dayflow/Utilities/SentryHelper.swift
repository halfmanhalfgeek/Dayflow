//
//  SentryHelper.swift
//  Dayflow
//
//  Safe wrapper for Sentry SDK calls.
//  Prevents errors when Sentry is not initialized (e.g., DSN not configured).
//

import Foundation
import Sentry

/// Thread-safe wrapper for Sentry SDK calls that gracefully handles uninitialized state.
final class SentryHelper {
  /// Tracks whether Sentry SDK has been successfully initialized.
  /// Managed through `setEnabled(_:)` / `startIfConfigured()`.
  private static let _isEnabled = NSLock()
  private static var _value = false

  static var isEnabled: Bool {
    get {
      _isEnabled.lock()
      defer { _isEnabled.unlock() }
      return _value
    }
    set {
      _isEnabled.lock()
      _value = newValue
      _isEnabled.unlock()
    }
  }

  /// Regex to detect home directory paths that may contain the username
  private static let homeDirPattern = try! NSRegularExpression(
    pattern: "/Users/[^/]+/",
    options: []
  )

  /// Enables or disables Sentry based on the shared telemetry preference.
  static func setEnabled(_ enabled: Bool) {
    if enabled {
      startIfConfigured()
      return
    }

    // Flip local gate first so helper calls become no-ops immediately.
    isEnabled = false
    SentrySDK.close()
  }

  /// Starts Sentry using app bundle configuration when a DSN is available.
  static func startIfConfigured() {
    guard !isEnabled else { return }

    let info = Bundle.main.infoDictionary
    let sentryDSN = info?["SentryDSN"] as? String ?? ""
    guard !sentryDSN.isEmpty else {
      isEnabled = false
      return
    }
    let sentryEnv = info?["SentryEnvironment"] as? String ?? "production"

    SentrySDK.start { options in
      options.dsn = sentryDSN
      options.environment = sentryEnv
      #if DEBUG
        options.debug = true
        options.tracesSampleRate = 1.0
      #else
        options.tracesSampleRate = 0.1
      #endif
      options.attachStacktrace = true
      options.enableAppHangTracking = true
      options.appHangTimeoutInterval = 5.0
      options.maxBreadcrumbs = 200
      options.enableAutoSessionTracking = true
      options.sendDefaultPii = false
      options.beforeSend = { event in
        return scrubEvent(event)
      }
    }
    isEnabled = true
  }

  /// Safely adds a breadcrumb to Sentry, only if the SDK is initialized.
  /// - Parameter breadcrumb: The breadcrumb to add
  static func addBreadcrumb(_ breadcrumb: Breadcrumb) {
    guard isEnabled else { return }
    SentrySDK.addBreadcrumb(breadcrumb)
  }

  /// Safely configures Sentry scope, only if the SDK is initialized.
  /// - Parameter configure: The scope configuration closure
  static func configureScope(_ configure: @escaping (Scope) -> Void) {
    guard isEnabled else { return }
    SentrySDK.configureScope(configure)
  }

  /// Safely starts a performance transaction, only if Sentry is initialized.
  static func startTransaction(name: String, operation: String) -> Span? {
    guard isEnabled else { return nil }
    return SentrySDK.startTransaction(name: name, operation: operation)
  }

  // MARK: - PII Scrubbing

  private static func scrubEvent(_ event: Event) -> Event? {
    // Strip user object and server name entirely
    event.user = nil
    event.serverName = nil

    // Scrub exception messages
    if let exceptions = event.exceptions {
      for exception in exceptions {
        exception.value = scrubString(exception.value) ?? exception.value
      }
    }

    // Scrub breadcrumbs
    if let breadcrumbs = event.breadcrumbs {
      for breadcrumb in breadcrumbs {
        if let message = breadcrumb.message {
          breadcrumb.message = scrubString(message)
        }
        if let data = breadcrumb.data {
          breadcrumb.data = scrubDictionary(data)
        }
      }
    }

    // Scrub context dictionaries
    if var context = event.context {
      for (key, inner) in context {
        context[key] = scrubDictionary(inner)
      }
      event.context = context
    }

    // Scrub tags
    if let tags = event.tags {
      var scrubbed: [String: String] = [:]
      for (k, v) in tags {
        scrubbed[k] = scrubString(v) ?? v
      }
      event.tags = scrubbed
    }

    // Scrub extra
    if let extra = event.extra {
      event.extra = scrubDictionary(extra)
    }

    return event
  }

  private static func scrubString(_ value: String?) -> String? {
    guard let value else { return nil }
    let range = NSRange(value.startIndex..., in: value)
    return homeDirPattern.stringByReplacingMatches(
      in: value, options: [], range: range,
      withTemplate: "/Users/[redacted]/"
    )
  }

  private static func scrubDictionary(_ dict: [String: Any]) -> [String: Any] {
    var out: [String: Any] = [:]
    for (k, v) in dict {
      out[k] = scrubValue(v)
    }
    return out
  }

  private static func scrubValue(_ value: Any) -> Any {
    if let str = value as? String {
      return scrubString(str) ?? str
    }
    if let dict = value as? [String: Any] {
      return scrubDictionary(dict)
    }
    return value
  }
}
