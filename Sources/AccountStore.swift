import Foundation
import UIKit
import SwifterSwift
@preconcurrency import SwiftyUserDefaults

// MARK: - Defaults Keys
public extension DefaultsKeys {
    var Instagram: DefaultsKey<Bool> { .init("kServiceInstagram", defaultValue: false) }
    var Twitter: DefaultsKey<Bool> { .init("kServiceTwitter", defaultValue: false) }
    var Pinterest: DefaultsKey<Bool> { .init("kServicePinterest", defaultValue: false) }
    var Tumblr: DefaultsKey<Bool> { .init("kServiceTumblr", defaultValue: false) }
    var Foursquare: DefaultsKey<Bool> { .init("kServiceFoursquare", defaultValue: false) }
    var Reddit: DefaultsKey<Bool> { .init("kServiceReddit", defaultValue: false) }
    var Github: DefaultsKey<Bool> { .init("kServiceGithub", defaultValue: false) }
    var Twitch: DefaultsKey<Bool> { .init("kServiceTwitch", defaultValue: false) }
    var FiveHundredpx: DefaultsKey<Bool> { .init("kServiceFiveHundredpx", defaultValue: false) }
    var TikTok: DefaultsKey<Bool> { .init("kServiceTikTok", defaultValue: false) }
}

// MARK: - AccountType.Code + Defaults
private extension AccountType.Code {
    
    var defaultsKey: DefaultsKey<Bool>? {
        switch self {
        case .instagram: return .init("kServiceInstagram", defaultValue: false)
        case .twitter: return .init("kServiceTwitter", defaultValue: false)
        case .pinterest: return .init("kServicePinterest", defaultValue: false)
        case .tumblr: return .init("kServiceTumblr", defaultValue: false)
        case .twitch: return .init("kServiceTwitch", defaultValue: false)
        case .reddit: return .init("kServiceReddit", defaultValue: false)
        case .foursquare: return .init("kServiceFoursquare", defaultValue: false)
        case .github: return .init("kServiceGithub", defaultValue: false)
        case .fiveHundredpx: return .init("kServiceFiveHundredpx", defaultValue: false)
        case .tiktok: return .init("kServiceTikTok", defaultValue: false)
        }
    }
}


// MARK: - AccountStore
public final class AccountStore {
    
    public static let instagram = AccountType(code: .instagram, webAddress: "instagram.com", description: "Instagram")
    public static let twitter = AccountType(code: .twitter, webAddress: "x.com", description: "X")
    public static let pinterest = AccountType(code: .pinterest, webAddress: "pinterest.com", description: "Pinterest")
    public static let tumblr = AccountType(code: .tumblr, webAddress: "tumblr.com", description: "Tumblr")
    public static let twitch = AccountType(code: .twitch, webAddress: "twitch.tv", description: "Twitch")
    public static let reddit = AccountType(code: .reddit, webAddress: "reddit.com", description: "Reddit")
    public static let foursquare = AccountType(code: .foursquare, webAddress: "foursquare.com", description: "Foursquare")
    public static let github = AccountType(code: .github, webAddress: "github.com", description: "Github")
    public static let fiveHundredpx = AccountType(code: .fiveHundredpx, webAddress: "500px.com", description: "500px")
    public static let tiktok = AccountType(code: .tiktok, webAddress: "tiktok.com", description: "TikTok")
    
    /// A list of all *supported* and *visiblet* account types.
    public static let all: [AccountType] = [
        instagram, twitter, pinterest, tumblr, twitch,
        reddit, foursquare, github, fiveHundredpx, tiktok
    ]
    
    /**
     A list of account types that are *enabled* by the user in settings.
     */
    @MainActor
    public static var accountTypes: [AccountType] {
        all.filter { type in
            guard let key = type.code.defaultsKey else { return false }
            return Defaults[key: key]
        }
    }
    
    /// Returns a specific `AccountType` from the list of all supported types.
    public static func accountType(for code: AccountType.Code) -> AccountType? {
        all.first { $0.code == code }
    }
}
