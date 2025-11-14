import Foundation
import SwiftyJSON

public final class TumblrBlog: GenericUser, @unchecked Sendable {
    
    public var name: String?
    public var postsCount: Int32 = 0
    
    public required init?(info: JSON) {
        
        if let uuid = info["uuid"].string, !uuid.isEmpty {
            
            let username = Self.parseUsername(from: info["url"].string)
            let fullname = info["name"].string ?? info["title"].string
            
            var avatarURL: URL?
            if let avatarArray = info["avatar"].array,
               let avatar64 = avatarArray.first(where: { $0["width"].int == 64 }),
               let avatar64UrlString = avatar64["url"].string {
                avatarURL = URL(string: avatar64UrlString)
            } else {
                avatarURL = URL(string: "https://api.tumblr.com/v2/blog/\(uuid)/avatar")
            }
            
            super.init(userId: uuid,
                       username: username,
                       fullname: fullname,
                       avatarPicture: avatarURL)
            
            self.postsCount = info["posts"].int32 ?? 0
            self.followersCount = info["followers"].int32 ?? 0
            
        } else if let name = info["name"].string, !name.isEmpty, let urlString = info["url"].string {
            
            let userId = name
            let username = name
            let fullname = name
            
            var avatarURL: URL?
            if let host = URL(string: urlString)?.host {
                avatarURL = URL(string: "https://api.tumblr.com/v2/blog/\(host)/avatar")
            }
            
            super.init(userId: userId,
                       username: username,
                       fullname: fullname,
                       avatarPicture: avatarURL)
            
            self.postsCount = 0
            self.followersCount = 0
            
        } else {
            return nil
        }
        
        self.name = info["name"].string ?? info["title"].string
    }
    
    private static func parseUsername(from urlString: String?) -> String? {
        guard let urlString else { return nil }
        
        if let url = URL(string: urlString) {
            if url.host?.contains("www.tumblr.com") == true, url.pathComponents.count > 2 {
                return url.pathComponents.last
            }
            else if let host = url.host, host.contains(".tumblr.com") {
                return host.replacingOccurrences(of: ".tumblr.com", with: "")
            }
        }
        
        return urlString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.tumblr.com/blog/view/", with: "")
            .replacingOccurrences(of: "tumblr.com/", with: "tumblr.com")
            .split(separator: ".").first.map(String.init)
    }
}
