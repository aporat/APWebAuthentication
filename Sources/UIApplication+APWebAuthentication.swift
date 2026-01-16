import Foundation
import UIKit

// MARK: - UIApplication Extensions

/// Extensions to `UIApplication` for app metadata and configuration.
///
/// These extensions provide convenient access to app information from Info.plist.
@MainActor
public extension UIApplication {
    
    /// The app's display name from Info.plist.
    ///
    /// Returns the display name shown to users on the home screen and in settings.
    /// Falls back to the bundle name if no display name is set, or empty string
    /// if neither is available.
    ///
    /// **Info.plist Keys Checked:**
    /// 1. `CFBundleDisplayName` - User-facing app name
    /// 2. `CFBundleName` - Technical bundle name (fallback)
    ///
    /// **Example:**
    /// ```swift
    /// let appName = UIApplication.shared.shortAppName
    /// print("Welcome to \(appName)!")
    /// ```
    ///
    /// - Returns: The app's display name, bundle name, or empty string
    var shortAppName: String {
        // Try display name first
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return displayName
        }
        
        // Fall back to bundle name
        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return bundleName
        }
        
        // Last resort
        return ""
    }
}
