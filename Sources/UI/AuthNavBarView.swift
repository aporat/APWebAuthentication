import SnapKit
import UIKit

final class AuthNavBarView: UIView {
    // MARK: - UI Elements

    lazy var imageView: UIImageView = {
        let view = UIImageView()

        view.image = UIImage(systemName: "lock.fill")
        view.tintColor = .black

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

    override func awakeFromNib() {
        super.awakeFromNib()
        setupSubviews()
    }

    fileprivate func setupSubviews() {
        addSubview(imageView)
        addSubview(titleLabel)

        setNeedsUpdateConstraints()
        hideSecure()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.userInterfaceStyle == .dark {
            imageView.tintColor = .white
        } else {
            imageView.tintColor = .black
        }
    }

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
