import Foundation
import UIKit

public final class TikTokWebAuthentication: SessionAuthentication {
    private struct AuthSettings: Codable {
        var signatureUrl: URL?
        var cookiesDomain: String?
        var cookieSessionIdField: String?
        var browserMode: ProviderBrowserMode?
        var customUserAgent: String?
        var sessionId: String?
        var svWebId: String?
        var sessionLastValidated: Date?
        var aid: String?
        var screenWidth: String?
        var screenHeight: String?
        var browserLanguage: String?
        var browserPlatform: String?
        var browserName: String?
        var browserVersion: String?
        var timezoneName: String?
    }
    
    public var signatureUrl: URL?
    public var secUid: String?
    public var svWebId: String?
    public var ttWebId: String?
    public var uidtt: String?
    public var sessionLastValidated = Date().adding(.hour, value: -2)
    
    public var aid: String = "1988"
    public var screenWidth: String = "375"
    public var screenHeight: String = "812"
    public var browserLanguage: String = "en"
    public var browserPlatform: String = "MacIntel"
    public var browserName: String = "Mozilla"
    public var browserVersion: String = "5.0+(iPhone;+CPU+iPhone+OS+13_2_3+like+Mac+OS+X)+AppleWebKit/605.1.15+(KHTML,+like+Gecko)+Version/13.0.3+Mobile/15E148+Safari/604.1"
    public var timezoneName: String = "America/Chicago"
    
    public required init() {
        super.init()
        cookieSessionIdField = "sessionid"
    }
    
    override public var isAuthorized: Bool {
        if let currentSessionId = sessionId, !currentSessionId.isEmpty { return true }
        return false
    }
    
    public func loadAuthTokens(forceLoad: Bool = false) {
        if forceLoad || sessionId == nil || svWebId == nil {
            cookieStorage.cookies?.forEach {
                if self.cookiesDomain.isEmpty || $0.domain.hasSuffix(self.cookiesDomain) {
                    if $0.name == "s_v_web_id", !$0.value.isEmpty {
                        self.svWebId = $0.value
                    } else if $0.name == "tt_webid_v2", !$0.value.isEmpty {
                        self.ttWebId = $0.value
                    } else if $0.name == "uid_tt", !$0.value.isEmpty {
                        self.uidtt = $0.value
                    } else if $0.name == cookieSessionIdField, !$0.value.isEmpty {
                        self.sessionId = $0.value
                    }
                }
            }
        }
    }
    
    // MARK: - Auth Settings
    
    override public func storeAuthSettings() {
        let settings = AuthSettings(
            signatureUrl: signatureUrl,
            cookiesDomain: cookiesDomain,
            cookieSessionIdField: cookieSessionIdField,
            browserMode: browserMode,
            customUserAgent: customUserAgent,
            sessionId: sessionId,
            svWebId: svWebId,
            sessionLastValidated: sessionLastValidated,
            aid: aid,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            browserLanguage: browserLanguage,
            browserPlatform: browserPlatform,
            browserName: browserName,
            browserVersion: browserVersion,
            timezoneName: timezoneName
        )
        
        if let authSettingsURL = authSettingsURL {
            let encoder = PropertyListEncoder()
            do {
                let data = try encoder.encode(settings)
                try data.write(to: authSettingsURL)
            } catch {
                print("⚠️ Failed to store TikTok settings: \(error)")
            }
        }
        
        storeCookiesSettings()
    }
    
    override public func loadAuthSettings() {
        if let authSettingsURL = authSettingsURL,
           let data = try? Data(contentsOf: authSettingsURL) {
            
            let decoder = PropertyListDecoder()
            do {
                let settings = try decoder.decode(AuthSettings.self, from: data)
                
                // Assign properties, falling back to current values if nil
                signatureUrl = settings.signatureUrl ?? signatureUrl
                cookiesDomain = settings.cookiesDomain ?? cookiesDomain
                cookieSessionIdField = settings.cookieSessionIdField ?? cookieSessionIdField
                browserMode = settings.browserMode ?? browserMode
                customUserAgent = settings.customUserAgent ?? customUserAgent
                sessionId = settings.sessionId ?? sessionId
                svWebId = settings.svWebId ?? svWebId
                sessionLastValidated = settings.sessionLastValidated ?? sessionLastValidated
                aid = settings.aid ?? aid
                screenWidth = settings.screenWidth ?? screenWidth
                screenHeight = settings.screenHeight ?? screenHeight
                browserLanguage = settings.browserLanguage ?? browserLanguage
                browserPlatform = settings.browserPlatform ?? browserPlatform
                browserName = settings.browserName ?? browserName
                browserVersion = settings.browserVersion ?? browserVersion
                timezoneName = settings.timezoneName ?? timezoneName
                
            } catch {
                print("⚠️ Failed to load TikTok settings: \(error)")
            }
        }
        
        loadCookiesSettings()
    }
}
