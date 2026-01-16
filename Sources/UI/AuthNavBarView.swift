import UIKit
import SnapKit

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
    
    // MARK: - Public Properties
    
    /// The text to display in the title label
    public var title: String? {
        get { titleLabel.text }
        set { titleLabel.text = newValue }
    }
    
    // MARK: - Private UI Components
    
    private lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "lock.fill")
        view.tintColor = .label
        view.contentMode = .scaleAspectFit
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 17)
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
    /// **Example:**
    /// ```swift
    /// navView.showSecure()
    /// ```
    public func showSecure() {
        imageView.isHidden = false

        imageView.snp.remakeConstraints { make in
            make.size.equalTo(20)
            make.centerY.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel.snp.leading).offset(-5)
        }

        titleLabel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview().offset(10) // Shift to center the lock + title combo
            make.centerY.equalToSuperview()
        }
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
        imageView.isHidden = true
        imageView.snp.removeConstraints()

        titleLabel.snp.remakeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    // MARK: - Private Setup

    private func setupView() {
        // Add subviews
        addSubview(imageView)
        addSubview(titleLabel)
        
        // Initialize in hidden state (no lock icon)
        hideSecure()
    }
}
