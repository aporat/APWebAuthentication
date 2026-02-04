import UIKit

/// A simple, customizable progress bar view.
@MainActor
public final class ProgressView: UIView {

    // MARK: - Public Properties

    /// The current progress value, ranging from 0.0 to 1.0.
    public private(set) var progress: Float = 0

    /// The color of the progress bar. Defaults to the standard system blue.
    public var progressTintColor: UIColor? = .systemBlue {
        didSet {
            bar.backgroundColor = progressTintColor
        }
    }

    /// The color of the track behind the progress bar. Defaults to clear.
    public var trackTintColor: UIColor? = .clear {
        didSet {
            backgroundColor = trackTintColor
        }
    }

    // MARK: - Private Properties

    private let bar = UIView()
    private var barWidthConstraint: NSLayoutConstraint!

    // MARK: - UIView Lifecycle

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        // Update constraint constant based on current bounds and progress
        barWidthConstraint.constant = bounds.width * CGFloat(progress)
    }

    // MARK: - Public Methods

    /// Updates the progress bar to a new value, with an optional animation.
    public func setProgress(_ newProgress: Float, animated: Bool) {
        // When setting progress, ensure the bar is visible.
        self.bar.alpha = 1.0

        self.progress = min(1.0, max(0.0, newProgress))
        barWidthConstraint.constant = self.bounds.width * CGFloat(self.progress)

        guard animated else {
            layoutIfNeeded()
            return
        }

        UIView.animate(withDuration: 0.25) {
            self.layoutIfNeeded()
        }
    }

    /// Animates the progress to completion (1.0), fades out, and then resets.
    public func finishProgress() {
        setProgress(1.0, animated: true)

        // After the progress animation completes, fade out the bar.
        UIView.animate(withDuration: 0.25, delay: 0.25, options: [], animations: {
            self.bar.alpha = 0
        }, completion: { _ in
            // Reset for the next use.
            self.progress = 0
        })
    }

    /// Animates the progress to the beginning (0.0) and fades out the bar.
    public func cancelProgress() {
        setProgress(0.0, animated: true)

        // Fade out the bar. A short delay can make it look smoother.
        UIView.animate(withDuration: 0.25, delay: 0.1, options: []) {
            self.bar.alpha = 0
        }
    }

    // MARK: - Private Setup

    private func setupView() {
        backgroundColor = trackTintColor

        bar.backgroundColor = progressTintColor
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)

        barWidthConstraint = bar.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            bar.topAnchor.constraint(equalTo: self.topAnchor),
            bar.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            barWidthConstraint
        ])
    }
}
