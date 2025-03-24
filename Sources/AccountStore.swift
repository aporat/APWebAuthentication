import SwifterSwift
import SwiftyUserDefaults
import UIKit

public extension DefaultsKeys {
    var Instagram: DefaultsKey<Bool> { .init("kServiceInstagram", defaultValue: false) }
    var Twitter: DefaultsKey<Bool> { .init("kServiceTwitter", defaultValue: false) }
    var Pinterest: DefaultsKey<Bool> { .init("kServicePinterest", defaultValue: false) }
    var Tumblr: DefaultsKey<Bool> { .init("kServiceTumblr", defaultValue: false) }
    var Foursquare: DefaultsKey<Bool> { .init("kServiceFoursquare", defaultValue: false) }
    var Reddit: DefaultsKey<Bool> { .init("kServiceReddit", defaultValue: false) }
    var Github: DefaultsKey<Bool> { .init("kServiceGithub", defaultValue: false) }
    var FiveHunderdsPx: DefaultsKey<Bool> { .init("kService500px", defaultValue: false) }
    var Twitch: DefaultsKey<Bool> { .init("kServiceTwitch", defaultValue: false) }
    var TikTok: DefaultsKey<Bool> { .init("kServiceTikTok", defaultValue: false) }
    var Parler: DefaultsKey<Bool> { .init("kServiceParler", defaultValue: true) }
}

public final class AccountStore {
    public static let instagram = AccountType(code: AccountType.Code.instagram, webAddress: "instagram.com", description: "Instagram", color: UIColor.Social.instagram)
    public static let twitter = AccountType(code: AccountType.Code.twitter, webAddress: "twitter.com", description: "Twitter", color: UIColor.Social.twitter)
    public static let pinterest = AccountType(code: AccountType.Code.pinterest, webAddress: "pinterest.com", description: "Pinterest", color: UIColor.Social.pinterest)
    public static let tumblr = AccountType(code: AccountType.Code.tumblr, webAddress: "tumblr.com", description: "Tumblr", color: UIColor.Social.tumblr)
    public static let twitch = AccountType(code: AccountType.Code.twitch, webAddress: "twitch.tv", description: "Twitch", color: UIColor(hex: 0x6441A5)!)
    public static let reddit = AccountType(code: AccountType.Code.reddit, webAddress: "reddit.com", description: "Reddit", color: UIColor.Social.reddit)
    public static let foursquare = AccountType(code: AccountType.Code.foursquare, webAddress: "foursquare.com", description: "Foursquare", color: UIColor.Social.foursquare)
    public static let github = AccountType(code: AccountType.Code.github, webAddress: "github.com", description: "Github", color: UIColor(hex: 0xCE4258)!)
    public static let fiveHundredpx = AccountType(code: AccountType.Code.fiveHundredpx, webAddress: "500px.com", description: "500px", color: UIColor.Social.px500)
    public static let tiktok = AccountType(code: AccountType.Code.tiktok, webAddress: "tiktok.com", description: "TikTok", color: UIColor(hex: 0xF61E55)!)
    public static let parler = AccountType(code: AccountType.Code.parler, webAddress: "parler.com", description: "Parler", color: UIColor(hex: 0xBE1E2C)!)

    public static var accountTypes: [AccountType] {
        var types = [AccountType]()

        if Defaults.Instagram {
            types.append(AccountStore.instagram)
        }

        if Defaults.Twitter {
            types.append(AccountStore.twitter)
        }

        if Defaults.Pinterest {
            types.append(AccountStore.pinterest)
        }

        if Defaults.TikTok {
            types.append(AccountStore.tiktok)
        }

        if Defaults.Tumblr {
            types.append(AccountStore.tumblr)
        }

        if Defaults.Twitch {
            types.append(AccountStore.twitch)
        }

        if Defaults.Parler {
            types.append(AccountStore.parler)
        }

        if Defaults.Reddit {
            types.append(AccountStore.reddit)
        }

        if Defaults.Foursquare {
            types.append(AccountStore.foursquare)
        }

        if Defaults.Github {
            types.append(AccountStore.github)
        }

        if Defaults.FiveHunderdsPx {
            types.append(AccountStore.fiveHundredpx)
        }

        return types
    }

    public class func accountType(_ code: AccountType.Code) -> AccountType? {
        if code == AccountType.Code.instagram {
            return AccountStore.instagram
        } else if code == AccountType.Code.twitter {
            return AccountStore.twitter
        } else if code == AccountType.Code.pinterest {
            return AccountStore.pinterest
        } else if code == AccountType.Code.tiktok {
            return AccountStore.tiktok
        } else if code == AccountType.Code.tumblr {
            return AccountStore.tumblr
        } else if code == AccountType.Code.twitch {
            return AccountStore.twitch
        } else if code == AccountType.Code.reddit {
            return AccountStore.reddit
        } else if code == AccountType.Code.foursquare {
            return AccountStore.foursquare
        } else if code == AccountType.Code.github {
            return AccountStore.github
        } else if code == AccountType.Code.fiveHundredpx {
            return AccountStore.fiveHundredpx
        } else if code == AccountType.Code.parler {
            return AccountStore.parler
        }

        return nil
    }
}
