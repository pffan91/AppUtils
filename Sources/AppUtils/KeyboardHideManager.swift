//
//  KeyboardHideManager.swift
//  AppUtils
//
//  Created by Vladyslav Semenchenko on 26/10/2024.
//

import UIKit

public final class KeyboardHideManager: NSObject {
    
    public var targets: [UIView] = [] {
        didSet {
            // Remove gestures from old targets
            oldValue.forEach { removeGesture(from: $0) }
            // Add gestures to new targets
            targets.forEach { addGesture(to: $0) }
        }
    }
    
    /// if true will apply gesture to view without subviews
    @IBInspectable public var scrollSupport: Bool = true
    
    /// Add UITapGestureRecognizer with action dismissKeyboard
    /// - Parameter target: A target that will be used to add gesture
    private func addGesture(to target: UIView) {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        target.addGestureRecognizer(gesture)
        if scrollSupport {
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
        }
    }
    
    /// Remove keyboard hide gesture from target view
    /// - Parameter target: A target to remove gesture from
    private func removeGesture(from target: UIView) {
        target.gestureRecognizers?.forEach { gesture in
            if let tapGesture = gesture as? UITapGestureRecognizer,
                tapGesture.view === self {
                target.removeGestureRecognizer(tapGesture)
            }
        }
    }
    
    /// Execute endEditing(true) for top superview to hide keyboard
    @objc private func dismissKeyboard() {
        targets.first?.window?.endEditing(true)
    }
}

extension KeyboardHideManager: UIGestureRecognizerDelegate {
    
    /// need for scrollSupport
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer.view == touch.view {
            return true
        }
        return false
    }
}
