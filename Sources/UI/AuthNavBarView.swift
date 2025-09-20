import UIKit
import SnapKit

/// A custom navigation bar view that displays a title and an optional security lock icon.
@MainActor
public final class AuthNavBarView: UIView {
    
    // MARK: - Public Properties
    
    /// The text to display in the title label.
    public var title: String? {
        get { titleLabel.text }
        set { titleLabel.text = newValue }
    }
    
    // MARK: - UI Elements
    
    private lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "lock.fill")
        view.tintColor = .label
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 17)
        label.textAlignment = .center
        return label
    }()

    // MARK: - UIView Lifecycle

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    /// Displays the security lock icon next to the title.
    public func showSecure() {
        imageView.isHidden = false

        imageView.snp.remakeConstraints { make in
            make.size.equalTo(20)
            make.centerY.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel.snp.leading).offset(-5)
        }

        titleLabel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview().offset(10) // Shift title to center the combined view
            make.centerY.equalToSuperview()
        }
    }

    /// Hides the security lock icon and centers the title.
    public func hideSecure() {
        imageView.isHidden = true
        imageView.snp.removeConstraints()

        titleLabel.snp.remakeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    // MARK: - Private Setup

    private func setupView() {
        addSubview(imageView)
        addSubview(titleLabel)
        
        // Set the initial state of the view.
        hideSecure()
    }
}
