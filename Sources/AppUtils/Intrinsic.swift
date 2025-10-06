import UIKit
import AppExtensions

class IntrinsicTableView: UITableView {
    
    override var intrinsicContentSize: CGSize {
        var size = self.contentSize
        if size.height > 0 {
            size.height += self.contentInset.top + self.contentInset.bottom
        }
        
        return size
    }
    
    override func reloadData() {
        self.invalidateIntrinsicContentSize()
        
        super.reloadData()
    }

}

class IntrinsicWithAutomaticHeightTableView: UITableView {
    private var storedHeight: CGFloat = 0
    override var intrinsicContentSize: CGSize {
        var size = self.contentSize
        if size.height > 0 {
            size.height = storedHeight
        }
        return size
    }
    
    override func reloadData() {
        self.invalidateIntrinsicContentSize()
        
        super.reloadData()
        DispatchQueue.main {
            self.storedHeight = self.contentSize.height
            self.invalidateIntrinsicContentSize()
            DispatchQueue.main {
                self.storedHeight = self.contentSize.height
                self.invalidateIntrinsicContentSize()
            }
        }
    }

}

class IntrinsicCollectionView: UICollectionView {
    
    override var intrinsicContentSize: CGSize {
        var size = self.contentSize
        if size.height > 0 {
            size.height += self.contentInset.top + self.contentInset.bottom
        }
        
        return size
    }
    
    override func reloadData() {
        self.invalidateIntrinsicContentSize()
        super.reloadData()
    }
    
}

class IntrinsicTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        var size = self.contentSize
        if size.height > 0 {
            size.height += self.contentInset.top + self.contentInset.bottom
        }
        
        return size
    }
       
    override var text: String! {
        get {
            return super.text
        }
        set {
            super.text = newValue
            self.invalidateIntrinsicContentSize()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if frame.size != intrinsicContentSize {
            self.invalidateIntrinsicContentSize()
        }
    }
}
