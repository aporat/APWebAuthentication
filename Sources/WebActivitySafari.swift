import UIKit

@MainActor
public final class WebActivitySafari: UIActivity {
    
    private var urlToOpen: URL?

    // --- Overrides ---

    override public class var activityCategory: UIActivity.Category {
        .action
    }

    override public var activityImage: UIImage? {
        UIImage(systemName: "safari")
    }

    override public var activityTitle: String {
        // Provide a more descriptive comment for localization.
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
            // Always call `activityDidFinish` to signal completion, even on failure.
            return activityDidFinish(false)
        }
        
        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            self?.activityDidFinish(success)
        }
    }
}
