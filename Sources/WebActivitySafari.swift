import UIKit

public final class WebActivitySafari: UIActivity, @unchecked Sendable {

    private var _urlToOpen: URL?
    private let urlLock = NSLock()
    private var urlToOpen: URL? {
        get { urlLock.withLock { _urlToOpen } }
        set { urlLock.withLock { _urlToOpen = newValue } }
    }

    override public class var activityCategory: UIActivity.Category {
        .action
    }

    override public var activityImage: UIImage? {
        UIImage(systemName: "safari.fill") ?? UIImage(systemName: "globe")
    }

    override public var activityTitle: String {
        NSLocalizedString("Open in Safari", comment: "Title for a button that opens a link in the Safari browser.")
    }

    override public var activityType: UIActivity.ActivityType? {
        let typeString = "com.aporat.apwebauthentication." + String(describing: Self.self)
        return UIActivity.ActivityType(rawValue: typeString)
    }

    override public func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        activityItems.contains { item in
            if let url = item as? URL, url.isWebURL() {
                return true
            }
            return false
        }
    }

    override public func prepare(withActivityItems activityItems: [Any]) {
        self.urlToOpen = activityItems.first { item in
            (item as? URL)?.isWebURL() ?? false
        } as? URL
    }

    override public func perform() {
        guard let url = urlToOpen else {
            DispatchQueue.main.async {
                self.activityDidFinish(false)
            }
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { success in
                self.activityDidFinish(success)
            }
        }
    }
}
