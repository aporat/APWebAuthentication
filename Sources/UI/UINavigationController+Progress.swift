import UIKit

// Use a private struct for the associated object key to avoid conflicts.
private enum AssociatedKeys {
    @MainActor static var progressView = "navigationControllerProgressView"
}

/// An extension to add a progress bar to a `UINavigationController`.
@MainActor
public extension UINavigationController {

    // MARK: - Public Properties

    /// The height of the progress bar. The default is 2.0.
    var progressHeight: CGFloat {
        get {
            // Find the height constraint and return its constant.
            return progressView.constraints.first { $0.firstAttribute == .height }?.constant ?? 0
        }
        set {
            // Find the height constraint and update its constant.
            progressView.constraints.first { $0.firstAttribute == .height }?.constant = newValue
        }
    }

    /// The color of the track behind the progress bar.
    var trackTintColor: UIColor? {
        get { progressView.trackTintColor }
        set { progressView.trackTintColor = newValue }
    }

    /// The color shown for the filled portion of the progress bar.
    var progressTintColor: UIColor? {
        get { progressView.progressTintColor }
        set { progressView.progressTintColor = newValue }
    }

    /// The current progress value, between 0.0 and 1.0.
    var progress: Float {
        get { progressView.progress }
        set { setProgress(newValue, animated: false) }
    }

    // MARK: - Private Computed Property

    private var progressView: ProgressView {
        // Try to retrieve the existing progress view.
        if let view = objc_getAssociatedObject(self, &AssociatedKeys.progressView) as? ProgressView {
            // Ensure it's on top of other navigation bar subviews.
            navigationBar.bringSubviewToFront(view)
            return view
        }

        // If it doesn't exist, create and configure a new one.
        let defaultHeight: CGFloat = 2.0
        let newProgressView = ProgressView(frame: .zero)
        newProgressView.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.addSubview(newProgressView)
        
        // Set up Auto Layout constraints to pin it to the bottom of the navigation bar.
        NSLayoutConstraint.activate([
            newProgressView.leadingAnchor.constraint(equalTo: navigationBar.leadingAnchor),
            newProgressView.trailingAnchor.constraint(equalTo: navigationBar.trailingAnchor),
            newProgressView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            newProgressView.heightAnchor.constraint(equalToConstant: defaultHeight)
        ])
        
        // Store the new progress view as an associated object for future access.
        objc_setAssociatedObject(self, &AssociatedKeys.progressView, newProgressView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        return newProgressView
    }

    // MARK: - Public Methods

    /// Adjusts the current progress shown by the receiver, optionally animating the change.
    func setProgress(_ progress: Float, animated: Bool) {
        progressView.setProgress(progress, animated: animated)
    }

    /// Animates the progress to completion (1.0) and then fades out.
    func finishProgress() {
        // The animation logic is now correctly encapsulated within the ProgressView.
        progressView.finishProgress()
    }

    /// Animates the progress to 0 and fades out.
    func cancelProgress() {
        // The animation logic is now correctly encapsulated within the ProgressView.
        progressView.cancelProgress()
    }
}
