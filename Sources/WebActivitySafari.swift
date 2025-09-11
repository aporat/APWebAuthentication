import UIKit

class WebActivitySafari: UIActivity {
    override class var activityCategory: UIActivity.Category {
        .action
    }

    override var activityImage: UIImage? {
        UIImage(systemName: "safari")
    }

    override var activityTitle: String {
        NSLocalizedString("Open in Safari", comment: "")
    }

    override var activityType: UIActivity.ActivityType? {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return nil
        }

        let type = bundleID + "." + String(describing: WebActivitySafari.self)
        return UIActivity.ActivityType(rawValue: type)
    }

    var activityDeepLink: String?

    var activityURL: URL?

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        for item in activityItems {
            guard let url = item as? URL else {
                continue
            }

            guard url.conformToHypertextProtocol() else {
                return false
            }

            return true
        }

        return false
    }

    override func prepare(withActivityItems activityItems: [Any]) {
        activityItems.forEach { item in
            guard let url = item as? URL, url.conformToHypertextProtocol() else {
                return
            }

            activityURL = url
            return
        }
    }

    override func perform() {
        guard let activityURL = activityURL else {
            return activityDidFinish(false)
        }

        UIApplication.shared.open(activityURL, options: [:]) { [weak self] opened in
            guard opened else {
                self?.activityDidFinish(false)
                return
            }
        }

        activityDidFinish(true)
    }
}
