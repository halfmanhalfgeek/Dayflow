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

    /// Matches macOS home-directory paths, e.g. /Users/jon/
    private static let homeDirPattern: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "/Users/[^/]+/", options: [])
    }()

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

            // Scrub PII from every event before it leaves the device.
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

    /// Removes personal data from a Sentry event before transmission.
    private static func scrubEvent(_ event: Event) -> Event {
        // Strip user object — prevents leaking IP, device name, or username.
        event.user = nil

        // Strip server name (machine hostname, e.g. "Jons-MacBook-Pro.local").
        event.serverName = nil

        // Scrub exception messages — error descriptions may embed file paths.
        if let exceptions = event.exceptions {
            for exception in exceptions {
                exception.value = scrubString(exception.value) ?? exception.value
            }
        }

        // Scrub breadcrumb messages and data dictionaries.
        if let breadcrumbs = event.breadcrumbs {
            for breadcrumb in breadcrumbs {
                breadcrumb.message = scrubString(breadcrumb.message)
                breadcrumb.data = scrubDictionary(breadcrumb.data)
            }
        }

        // Scrub context values (e.g. app_state set in Layout.swift).
        if let context = event.context {
            var scrubbed: [String: [String: Any]] = [:]
            for (key, innerDict) in context {
                scrubbed[key] = scrubDictionary(innerDict) ?? innerDict
            }
            event.context = scrubbed
        }

        // Scrub tags and extra.
        if let tags = event.tags {
            event.tags = tags.mapValues { scrubString($0) ?? $0 }
        }
        if let extra = event.extra {
            event.extra = scrubDictionary(extra)
        }

        return event
    }

    /// Replaces `/Users/<username>/` with `/Users/[redacted]/` in a string.
    private static func scrubString(_ input: String?) -> String? {
        guard let input, let pattern = homeDirPattern else { return input }
        let range = NSRange(input.startIndex..., in: input)
        return pattern.stringByReplacingMatches(
            in: input, range: range,
            withTemplate: "/Users/[redacted]/"
        )
    }

    /// Recursively scrubs string values in a dictionary.
    private static func scrubDictionary(_ dict: [String: Any]?) -> [String: Any]? {
        guard let dict else { return nil }
        var result: [String: Any] = [:]
        for (key, value) in dict {
            result[key] = scrubValue(value)
        }
        return result
    }

    private static func scrubValue(_ value: Any) -> Any {
        if let str = value as? String {
            return scrubString(str) ?? str
        } else if let dict = value as? [String: Any] {
            return scrubDictionary(dict) as Any
        } else if let arr = value as? [Any] {
            return arr.map { scrubValue($0) }
        }
        return value
    }

}
