//
//  ShakeDetectionWindow.swift
//  AppUtils
//
//  Created by Vladyslav Semenchenko on 27/05/2025.
//

import UIKit

public protocol ShakeDetectionDelegate: AnyObject {
    func didDetectShake(from viewController: UIViewController?)
}

public class ShakeDetectingWindow: UIWindow {

    public weak var shakeDelegate: ShakeDetectionDelegate?

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            let topViewController = topMostViewController(UIApplication.shared.windows.first(where: \.isKeyWindow)?.rootViewController)
            shakeDelegate?.didDetectShake(from: topViewController)
        }
    }

    // MARK: - Private

    private func topMostViewController(_ vc: UIViewController? = nil) -> UIViewController? {
        if let presentedViewController = vc?.presentedViewController {
            return topMostViewController(presentedViewController)
        }

        if let navigationController = vc as? UINavigationController {
            return topMostViewController(navigationController.visibleViewController) ?? vc
        }

        if let tabBarController = vc as? UITabBarController {
            return topMostViewController(tabBarController.selectedViewController) ?? vc
        }

        return vc
    }
}
