import SnapKit
import UIKit

// MARK: - AuthNavBarView

/// A custom navigation bar title view that displays text with an optional security lock icon.
///
/// This view is designed to be used as a `navigationItem.titleView` in authentication flows,
/// providing visual feedback about secure connections.
///
/// **Features:**
/// - Displays a centered title
/// - Shows/hides a lock icon to indicate security status
/// - Automatically adjusts layout based on lock icon visibility
///
/// **Example Usage:**
/// ```swift
/// let navView = AuthNavBarView()
/// navView.title = "instagram.com"
/// navView.showSecure() // Shows lock icon
/// navigationItem.titleView = navView
/// ```
@MainActor
public final class AuthNavBarView: UIView {

    // MARK: - Constants

    private enum Constants {
        static let lockIconSize: CGFloat = 20
        static let lockIconSpacing: CGFloat = 5
        static let titleCenterOffset: CGFloat = 10
        static let titleFontSize: CGFloat = 17
    }

    // MARK: - Public Properties

    /// The text to display in the title label
    public var title: String? {
        get { titleLabel.text }
        set { titleLabel.text = newValue }
    }

    // MARK: - Private UI Components

    private lazy var lockImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "lock.fill")
        imageView.tintColor = .label
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: Constants.titleFontSize)
        label.textAlignment = .center
        label.textColor = .label
        return label
    }()

    // MARK: - Initialization

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods

    /// Shows the security lock icon next to the title.
    ///
    /// The lock icon appears to the left of the title text, and the title is
    /// shifted slightly to keep the combined view centered.
    ///
    /// - Note: The title is offset by `Constants.titleCenterOffset` to visually center
    ///   the lock icon and title combination.
    ///
    /// **Example:**
    /// ```swift
    /// navView.showSecure()
    /// ```
    public func showSecure() {
        lockImageView.isHidden = false
        updateConstraintsForSecureState()
    }

    /// Hides the security lock icon and centers the title.
    ///
    /// This is the default state. The title is centered without any icon.
    ///
    /// **Example:**
    /// ```swift
    /// navView.hideSecure()
    /// ```
    public func hideSecure() {
        lockImageView.isHidden = true
        updateConstraintsForNonSecureState()
    }

    // MARK: - Private Methods - Setup

    private func setupView() {
        addSubview(lockImageView)
        addSubview(titleLabel)

        // Initialize in hidden state (no lock icon)
        hideSecure()
    }

    // MARK: - Private Methods - Layout

    private func updateConstraintsForSecureState() {
        lockImageView.snp.remakeConstraints { make in
            make.size.equalTo(Constants.lockIconSize)
            make.centerY.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel.snp.leading).offset(-Constants.lockIconSpacing)
        }

        titleLabel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview().offset(Constants.titleCenterOffset)
            make.centerY.equalToSuperview()
        }
    }

    private func updateConstraintsForNonSecureState() {
        lockImageView.snp.removeConstraints()

        titleLabel.snp.remakeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
