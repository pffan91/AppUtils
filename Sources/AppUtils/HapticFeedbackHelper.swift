//
//  HapticFeedbackHelper.swift
//  AppUtils
//
//  Created by Vladyslav Semenchenko on 01/02/2025.
//

import UIKit

public class HapticFeedbackHelper {

    public static let shared = HapticFeedbackHelper()

    private init() {}

    // MARK: - Impact Feedback

    public func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Notification Feedback

    public func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    // MARK: - Selection Feedback

    public func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    // MARK: - Custom Feedback

    public func customImpact(intensity: CGFloat) {
        if #available(iOS 13.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.prepare()
            generator.impactOccurred(intensity: intensity)
        } else {
            // Fallback for earlier versions
            impact(style: .medium)
        }
    }
}
