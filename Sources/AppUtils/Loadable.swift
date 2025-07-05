//
//  Loadable.swift
//  AppUtils
//
//  Created by Vladyslav Semenchenko on 12/01/2025.
//

import UIKit

/// A protocol for showing/hiding a loader (spinner) on a view controller.
public protocol Loadable: AnyObject {
    /// Show the loading indicator
    func showLoader(style: UIActivityIndicatorView.Style)

    /// Hide the loading indicator
    func hideLoader()
}

// A unique key to attach our loader via associated objects
private var loaderViewKey: UInt8 = 0

public extension Loadable where Self: UIViewController {

    /// A computed property that gets/sets our loader via associated objects
    private var loaderView: UIActivityIndicatorView? {
        get {
            return objc_getAssociatedObject(self, &loaderViewKey) as? UIActivityIndicatorView
        }
        set {
            objc_setAssociatedObject(self, &loaderViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func showLoader(style: UIActivityIndicatorView.Style = .medium) {
        // If loader already exists, don't recreate it
        if loaderView == nil {
            let indicator = UIActivityIndicatorView(style: style)
            indicator.hidesWhenStopped = true
            indicator.center = view.center
            view.addSubview(indicator)
            loaderView = indicator
        }
        loaderView?.startAnimating()
    }

    func hideLoader() {
        loaderView?.stopAnimating()
        loaderView?.removeFromSuperview()
        loaderView = nil
    }
}
