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

// MARK: - AccountStore
public final class AccountStore {
    
    public static let instagram = AccountType(code: .instagram, webAddress: "instagram.com", description: "Instagram")!
    public static let twitter = AccountType(code: .twitter, webAddress: "x.com", description: "X")!
    public static let pinterest = AccountType(code: .pinterest, webAddress: "pinterest.com", description: "Pinterest")!
    public static let tumblr = AccountType(code: .tumblr, webAddress: "tumblr.com", description: "Tumblr")!
    public static let twitch = AccountType(code: .twitch, webAddress: "twitch.tv", description: "Twitch")!
    public static let reddit = AccountType(code: .reddit, webAddress: "reddit.com", description: "Reddit")!
    public static let foursquare = AccountType(code: .foursquare, webAddress: "foursquare.com", description: "Foursquare")!
    public static let github = AccountType(code: .github, webAddress: "github.com", description: "Github")!
    public static let fiveHundredpx = AccountType(code: .fiveHundredpx, webAddress: "500px.com", description: "500px")!
    public static let tiktok = AccountType(code: .tiktok, webAddress: "tiktok.com", description: "TikTok")!

    public static let all: [AccountType] = [
        instagram, twitter, pinterest, tumblr, twitch,
        reddit, foursquare, github, fiveHundredpx, tiktok
    ]
    
    public static var accountTypes: [AccountType] {
        all.filter { type in
            switch type.code {
            case .instagram: return Defaults.Instagram
            case .twitter: return Defaults.Twitter
            case .pinterest: return Defaults.Pinterest
            case .tumblr: return Defaults.Tumblr
            case .twitch: return Defaults.Twitch
            case .reddit: return Defaults.Reddit
            case .foursquare: return Defaults.Foursquare
            case .github: return Defaults.Github
            case .fiveHundredpx: return Defaults.FiveHundredpx
            case .tiktok: return Defaults.TikTok
            default: return false
            }
        }
    }

    public class func accountType(for code: AccountType.Code) -> AccountType? {
        all.first { $0.code == code }
    }
}

