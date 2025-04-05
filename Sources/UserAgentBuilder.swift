import UIKit

struct UserAgentBuilder {
    
    // These parts of UA are frozen in WebKit.
    private let kernelVersion = "15E148"
    private let safariBuildNumber = "604.1"
    private let webkitVersion = "605.1.15"
    
    private let device: UIDevice
    private let os: OperatingSystemVersion
    
    /// - parameter iOSVersion: iOS version of the created UA. Both desktop and mobile UA differ between iOS versions.
    public init(device: UIDevice = .current,
                iOSVersion: OperatingSystemVersion = ProcessInfo().operatingSystemVersion) {
        self.device = device
        self.os = iOSVersion
    }
    
    /// Creates Safari-like user agent.
    /// - parameter desktopMode: Wheter to use Mac's Safari UA or regular mobile iOS UA.
    /// The desktop UA is taken from iOS Safari `Request desktop website` feature.
    ///
    /// - returns: A proper user agent to use in WKWebView and url requests.
    public func build(desktopMode: Bool) -> String {
        
        if desktopMode { return desktopUA }
        
        return """
        Mozilla/5.0 (\(cpuInfo)) \
        AppleWebKit/\(webkitVersion) (KHTML, like Gecko) \
        Version/\(safariVersion) \
        Mobile/\(kernelVersion) \
        Safari/\(safariBuildNumber)
        """
    }
    
    private var desktopUA: String {
        return
            """
        Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) \
        AppleWebKit/605.1.15 (KHTML, like Gecko) \
        Version/18.4 \
        Safari/605.1.15
        """

        
    }
    
    private var cpuInfo: String {
        var currentDevice = device.model
        // Only use first part of device name(so "iPod Touch" becomes "iPod")
        if let deviceNameFirstPart = currentDevice.split(separator: " ").first {
            currentDevice = String(deviceNameFirstPart)
        }
        
        let platform = device.userInterfaceIdiom == .pad ? "OS" : "iPhone OS"
        
        return "\(currentDevice); CPU \(platform) \(osVersion) like Mac OS X"
    }
    
    /// 'Version/13.0' part of UA. It seems to be based on Safaris build number.
    private var osVersion: String {
        switch os.majorVersion {
        case 12: return "12_4_1"
        case 13: return "13_6_1"
        case 14: return "14_3"
        default: return "\(os.majorVersion)_0"
            
        }
    }
    
    /// 'Version/13.0' part of UA. It seems to be based on Safaris build number.
    private var safariVersion: String {
        switch os.majorVersion {
        case 12: return "12.1.2"
        case 13: return "13.1.2"
        case 14: return "14.0.2"
        default: return "\(os.majorVersion).0"
            
        }
    }
}
