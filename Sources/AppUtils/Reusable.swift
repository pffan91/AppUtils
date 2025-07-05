//
//  Reusable.swift
//  AppUtils
//
//  Created by Vladyslav Semenchenko on 05/11/2024.
//

import UIKit

/// Protocol implementation class must be registered as class for code-only cell, as nib for XIB-cell or set as class & reuse identifier for storyboard prototype cell.
public protocol Reusable { }

public extension Reusable {
    static var ReuseIdentifier: String { return String(describing: self) }
}

public extension Reusable where Self: UITableViewCell {

    static func registerCell(in tableView: UITableView) {
        tableView.register(self, forCellReuseIdentifier: ReuseIdentifier)
    }

    static func dequeueReusableCell(from tableView: UITableView, for indexPath: IndexPath) -> Self {
        return tableView.dequeueReusableCell(withIdentifier: ReuseIdentifier, for: indexPath) as! Self
    }
}

public extension Reusable where Self: UITableViewHeaderFooterView {

    static func registerHeaderFooter(in tableView: UITableView) {
        tableView.register(self, forHeaderFooterViewReuseIdentifier: ReuseIdentifier)
    }

    static func dequeueReusableHeaderFooter(from tableView: UITableView) -> Self {
        return tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseIdentifier) as! Self
    }
}

public extension Reusable where Self: UICollectionViewCell {

    static func registerCell(in collectionView: UICollectionView) {
        collectionView.register(self, forCellWithReuseIdentifier: ReuseIdentifier)
    }

    static func dequeueReusableCell(from collectionView: UICollectionView, for indexPath: IndexPath) -> Self {
        return collectionView.dequeueReusableCell(withReuseIdentifier: ReuseIdentifier, for: indexPath) as! Self
    }
}

public extension Reusable where Self: UICollectionReusableView {

    static func registerSupplementaryView(ofKind kind: String, in collectionView: UICollectionView) {
        collectionView.register(self, forSupplementaryViewOfKind: kind, withReuseIdentifier: ReuseIdentifier)
    }

    static func dequeueReusableSupplementaryView(from collectionView: UICollectionView, ofKind kind: String, for indexPath: IndexPath) -> Self {
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ReuseIdentifier, for: indexPath) as! Self
    }
}
