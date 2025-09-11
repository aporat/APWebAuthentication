import UIKit
import SnapKit

@MainActor
final class AuthNavBarView: UIView {
    // MARK: - UI Elements

    lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "lock.fill")
        // Set initial tint color based on the current trait collection.
        if self.traitCollection.userInterfaceStyle == .dark {
            view.tintColor = .white
        } else {
            view.tintColor = .black
        }
        return view
    }()

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 17)
        label.textAlignment = .center
        return label
    }()

    // MARK: - UIView

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setupSubviews() {
        addSubview(imageView)
        addSubview(titleLabel)

        // Register for changes to the user interface style.
        self.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: AuthNavBarView, previousTraitCollection: UITraitCollection) in
            if self.traitCollection.userInterfaceStyle == .dark {
                self.imageView.tintColor = .white
            } else {
                self.imageView.tintColor = .black
            }
        }
        
        setNeedsUpdateConstraints()
        hideSecure()
    }

    // The deprecated method has been removed.

    public func showSecure() {
        imageView.isHidden = false

        imageView.snp.remakeConstraints { make in
            make.size.equalTo(20)
            make.centerY.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel.snp.leading).offset(-5)
        }

        titleLabel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
        }
    }

    public func hideSecure() {
        imageView.isHidden = true

        imageView.snp.removeConstraints()

        titleLabel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }
}
