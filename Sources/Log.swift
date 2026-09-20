import Foundation
import OSLog

/// Loggers used across the package.
///
/// Diagnostics go through `os.Logger` rather than `print` so they carry a
/// subsystem and category, stay out of release stdout, and — importantly for
/// an authentication library — get the privacy annotations that keep tokens
/// and cookie values from being interpolated into the system log. Interpolate
/// error descriptions as `.public` and anything derived from credentials as
/// the default `.private`.
enum Log {

    private static let subsystem = "com.apwebauthentication"

    /// Keychain reads and writes for stored credentials and cookies.
    static let keychain = Logger(subsystem: subsystem, category: "keychain")

    /// OAuth token acquisition and refresh.
    static let oauth = Logger(subsystem: subsystem, category: "oauth")
}
