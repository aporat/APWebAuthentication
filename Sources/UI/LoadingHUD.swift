import UIKit

// MARK: - LoadingHUD

/// A dark translucent spinner laid over a host view while a sign-in step runs.
@MainActor
final class LoadingHUD: UIView {

    private let box: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterialDark))
        view.layer.cornerRadius = 12
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .large)
        view.color = .white
        view.hidesWhenStopped = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        accessibilityViewIsModal = true

        box.contentView.addSubview(activityIndicator)
        addSubview(box)
        NSLayoutConstraint.activate([
            box.centerXAnchor.constraint(equalTo: centerXAnchor),
            box.centerYAnchor.constraint(equalTo: centerYAnchor),
            box.widthAnchor.constraint(equalToConstant: 96),
            box.heightAnchor.constraint(equalToConstant: 96),
            activityIndicator.centerXAnchor.constraint(equalTo: box.contentView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: box.contentView.centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Lays the HUD over `view`; a no-op while it is already there.
    func show(in view: UIView) {
        guard superview !== view else { return }
        removeFromSuperview()

        frame = view.bounds
        view.addSubview(self)
        activityIndicator.startAnimating()
        layoutIfNeeded()

        alpha = 0
        box.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            self.alpha = 1
            self.box.transform = .identity
        }
    }

    func dismiss() {
        guard superview != nil else { return }
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn, .beginFromCurrentState]) {
            self.alpha = 0
        } completion: { _ in
            // A show() during the fade re-adds the view; leave that one alone.
            guard self.alpha == 0 else { return }
            self.activityIndicator.stopAnimating()
            self.removeFromSuperview()
            self.alpha = 1
            self.box.transform = .identity
        }
    }
}
