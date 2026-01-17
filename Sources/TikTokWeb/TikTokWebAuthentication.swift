import Foundation
import UIKit

@MainActor
public final class TikTokWebAuthentication: SessionAuthentication {
    
    private struct AuthSettings: Codable, Sendable {
        var signatureUrl: URL?
        var browserMode: UserAgentMode?
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
    public var username: String?
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
    
    override public var isAuthorized: Bool {
        if let currentSessionId = sessionId, !currentSessionId.isEmpty { return true }
        return false
    }
    
    public func loadAuthTokens(forceLoad: Bool = false) {
        if forceLoad || sessionId == nil || svWebId == nil {
            cookieStorage.cookies?.forEach {
                    if $0.name == "s_v_web_id", !$0.value.isEmpty {
                        self.svWebId = $0.value
                    } else if $0.name == "tt_webid_v2", !$0.value.isEmpty {
                        self.ttWebId = $0.value
                    } else if $0.name == "uid_tt", !$0.value.isEmpty {
                        self.uidtt = $0.value
                    } else if $0.name == "sessionid", !$0.value.isEmpty {
                        self.sessionId = $0.value
                    }
            }
        }
    }
    
    // MARK: - Auth Settings
    
    override public func storeAuthSettings() async {
        let settings = AuthSettings(
            signatureUrl: signatureUrl,
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
        
        guard let authSettingsURL = authSettingsURL else { return }
        
        do {
            let data = try PropertyListEncoder().encode(settings)
            
            try await Task.detached {
                try data.write(to: authSettingsURL)
            }.value
        } catch {
            print("⚠️ Failed to store TikTok settings: \(error)")
        }
        
        await storeCookiesSettings()
    }
    
    override public func loadAuthSettings() async {
        guard let authSettingsURL = authSettingsURL else {
            await loadCookiesSettings()
            return
        }
        
        do {
            let data = try await Task.detached {
                try Data(contentsOf: authSettingsURL)
            }.value
            
            let settings = try PropertyListDecoder().decode(AuthSettings.self, from: data)
            
            signatureUrl = settings.signatureUrl ?? signatureUrl
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
        
        await loadCookiesSettings()
    }
}
