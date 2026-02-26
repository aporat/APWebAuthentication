import Foundation

// MARK: - Account Type

/// Represents a social media account type/platform.
///
/// Encapsulates platform identification with a unique code, web address, and display name.
///
/// **Example:**
/// ```swift
/// let instagram = AccountType(
///     code: .instagram,
///     webAddress: "instagram.com",
///     description: "Instagram"
/// )
///
/// print(instagram.description) // "Instagram"
/// print(instagram.fullWebAddress) // "https://instagram.com"
/// ```
public struct AccountType: Hashable, Identifiable, Sendable {

    // MARK: - Properties

    /// Unique identifier based on the account code.
    public var id: String {
        code.rawValue
    }

    /// The platform's unique code identifier.
    public var code: Code

    /// The platform's web address (without protocol).
    public var webAddress: String

    /// User-facing display name for the platform.
    public var description: String

    // MARK: - Initialization

    /// Creates a new account type.
    ///
    /// - Parameters:
    ///   - code: The unique platform code
    ///   - webAddress: The platform's web address (without protocol)
    ///   - description: User-facing platform name
    public init(code: Code, webAddress: String, description: String) {
        self.code = code
        self.webAddress = webAddress
        self.description = description
    }

    // MARK: - Computed Properties

    /// Returns the full HTTPS web address for the platform.
    public var fullWebAddress: String {
        "https://\(webAddress)"
    }

    /// Returns a URL object for the platform's web address.
    public var url: URL? {
        URL(string: fullWebAddress)
    }

    // MARK: - Hashable Conformance

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: AccountType, rhs: AccountType) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Account Type Code

public extension AccountType {

    /// Unique identifier codes for supported social media platforms.
    ///
    /// Each code uses reverse domain notation (e.g., `com.apple.instagram`)
    /// to ensure global uniqueness.
    enum Code: String, Hashable, Sendable, CaseIterable {
        case twitter = "com.apple.twitter"
        case instagram = "com.apple.instagram"
        case fiveHundredpx = "com.apple.500px"
        case tiktok = "com.apple.tiktok"
        case tumblr = "com.apple.tumblr"
        case twitch = "com.apple.twitch"
        case pinterest = "com.apple.pinterest"
        case foursquare = "com.apple.foursquare"
        case reddit = "com.apple.reddit"
        case github = "com.apple.github"

        // MARK: - Computed Properties

        /// Returns a user-friendly platform name.
        public var platformName: String {
            switch self {
            case .twitter:
                return "Twitter"
            case .instagram:
                return "Instagram"
            case .fiveHundredpx:
                return "500px"
            case .tiktok:
                return "TikTok"
            case .tumblr:
                return "Tumblr"
            case .twitch:
                return "Twitch"
            case .pinterest:
                return "Pinterest"
            case .foursquare:
                return "Foursquare"
            case .reddit:
                return "Reddit"
            case .github:
                return "GitHub"
            }
        }

        /// Returns the platform identifier without the domain prefix.
        public var shortIdentifier: String {
            rawValue.replacingOccurrences(of: "com.apple.", with: "")
        }
    }
}

// MARK: - CustomStringConvertible

extension AccountType: CustomStringConvertible {

    /// Returns the platform's display name.
    public var stringDescription: String {
        description
    }
}

// MARK: - CustomDebugStringConvertible

extension AccountType: CustomDebugStringConvertible {

    /// Returns a detailed debug description.
    public var debugDescription: String {
        "AccountType(code: \(code.rawValue), webAddress: \(webAddress), description: \(description))"
    }
}
