//
//  ViewController.swift
//  DragToReorderCollectionView
//

import UIKit

class ViewController: UIViewController, DraggableCellDelegate{
    // apple says that outlets should be weak implicitly unwrapped optional
    @IBOutlet weak var collectionView: UICollectionView!

    var editButtonItem: UIBarButtonItem!
    var doneButtonItem: UIBarButtonItem!
    
    var pannedIndexPath: NSIndexPath?
    var pannedView: UIImageView?
    
    var dataValues:[Int] = {
        var tmp = [Int]()
        for i in 0 ..< 100 {
            tmp.append(i)
        }
        return tmp
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        editButtonItem = UIBarButtonItem(barButtonSystemItem: .Edit, target: self, action: "editAction:")
        doneButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "editAction:")
        
        self.navigationItem.rightBarButtonItem = editButtonItem;
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func editAction(buttonItem: UIBarButtonItem) {
        if editing {
            // end editing
            self.navigationItem.setRightBarButtonItem(editButtonItem, animated: true)
            
        } else {
            // begin editing
            self.navigationItem.setRightBarButtonItem(doneButtonItem, animated: true)
            
        }
        editing = !editing
        collectionView.reloadSections(NSIndexSet(index:0))
    }
    
    // MARK: UICollectionViewDatasource
    
    func collectionView(collectionView: UICollectionView!, numberOfItemsInSection section: Int) -> Int {
        return dataValues.count
    }
    
    func collectionView(collectionView: UICollectionView!, cellForItemAtIndexPath indexPath: NSIndexPath!) ->
        UICollectionViewCell! {
            let cell = collectionView.dequeueReusableCellWithReuseIdentifier("defaultCell", forIndexPath: indexPath) as DraggableCell
            cell.delegate = self
            
            cell.tag = indexPath.item
            cell.label.text = dataValues[indexPath.item].description
            
            if editing {
                cell.deleteButton.hidden = false
            } else {
                cell.deleteButton.hidden = true
            }
            
            cell.editing = editing
            
            return cell
    }

    // MARK: DraggableCellDelegate
    
    func draggableCellDeleteButtonTapped(cell: DraggableCell) {
        // delete
        if let path = collectionView.indexPathForCell(cell) {
            dataValues.removeAtIndex(path.item)
            collectionView.performBatchUpdates({
                self.collectionView.deleteItemsAtIndexPaths([ path ])
                }, completion: { succes in self.collectionView.reloadData() })
        }
    }
    
    func draggableCell(cell: DraggableCell, pannedWithGestureRecognizer gestureRecognizer:UIPanGestureRecognizer) {
        if !editing {
            return
        }
        
        if gestureRecognizer.state == .Began {

            let point = gestureRecognizer.locationInView(collectionView)
            if let path = collectionView.indexPathForItemAtPoint(point) {
                cell.hidden = true
                pannedIndexPath = path
                
                // create image for dragging
                UIGraphicsBeginImageContextWithOptions(cell.frame.size, cell.opaque, 0)
                cell.contentView.layer.renderInContext(UIGraphicsGetCurrentContext())
                let image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                // and add
                pannedView = UIImageView(image: image)
                pannedView!.backgroundColor = UIColor.whiteColor()
                pannedView!.layer.borderColor = cell.layer.borderColor
                pannedView!.layer.borderWidth = cell.layer.borderWidth
                pannedView!.center = gestureRecognizer.locationInView(self.view)
                self.view.addSubview(pannedView!)
            }
            
        } else if gestureRecognizer.state == .Changed {
            if pannedIndexPath == nil {
                return
            }
            
            let destPoint = gestureRecognizer.locationInView(self.view)
            pannedView!.center = destPoint
            
            let point = gestureRecognizer.locationInView(collectionView)
            if let indexPath = collectionView.indexPathForItemAtPoint(point) {
                if indexPath != pannedIndexPath {
                    // replace
                    let moved = dataValues.removeAtIndex(pannedIndexPath!.item)
                    dataValues.insert(moved, atIndex: indexPath.item)
                    
                    collectionView.moveItemAtIndexPath(pannedIndexPath!, toIndexPath: indexPath)
                    pannedIndexPath = indexPath
                }
            }
            
            // scroll if necessary
            let visibleItems = collectionView.indexPathsForVisibleItems()
            if visibleItems.count > 0 {
                let visibles = NSArray(array: visibleItems)
                let sorted = NSArray(array: visibles.sortedArrayUsingDescriptors([ NSSortDescriptor(key: "item", ascending: true) ]))
                
                if destPoint.y > CGRectGetHeight(self.view.frame) - 50 {
                    var lastPath = sorted.lastObject as NSIndexPath
                    if lastPath.item + 1 < dataValues.count {
                        // scroll forward
                        let attr = collectionView.collectionViewLayout.layoutAttributesForItemAtIndexPath(lastPath)
                        var rect = attr.frame
                        rect.origin.y += 100
                        
                        collectionView.scrollRectToVisible(rect, animated: true)
                    }
                    
                } else if destPoint.y < 150 {
                    // scroll upward
                    let firstPath = sorted.firstObject as NSIndexPath
                    let attr = collectionView!.collectionViewLayout.layoutAttributesForItemAtIndexPath(firstPath)
                    var rect = attr.frame
                    rect.origin.y -= 100
                    
                    if rect.origin.y >= 0 {
                        collectionView.scrollRectToVisible(rect, animated: true)
                    }
                }
            }
        
        } else {
            // end dragging
            cell.hidden = false
            
            pannedView?.removeFromSuperview()
            pannedView = nil
        
            pannedIndexPath = nil
        }
    }
}

// MARK: DraggableCellDelegate

@objc protocol DraggableCellDelegate {
    optional func draggableCellDeleteButtonTapped(cell: DraggableCell)
    optional func draggableCell(cell: DraggableCell, pannedWithGestureRecognizer gestureRecognizer:UIPanGestureRecognizer)
}

// MARK: DraggableCell

class DraggableCell : UICollectionViewCell, UIGestureRecognizerDelegate {
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var label: UILabel!
    
    weak var delegate: DraggableCellDelegate?
    
    var editing = false
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.layer.borderColor = UIColor.lightGrayColor().CGColor
        self.layer.borderWidth = 1.0
        
        let gesture = UIPanGestureRecognizer(target: self, action: "panAction:")
        gesture.delegate = self
        self.addGestureRecognizer(gesture)
    }
    
    override func awakeFromNib() {
        deleteButton.transform = CGAffineTransformMakeRotation(CGFloat(45 * M_PI / 180))
    }
    
    func panAction(gesture: UIPanGestureRecognizer) {
        // invoke protocol method
        delegate?.draggableCell?(self, pannedWithGestureRecognizer: gesture)
    }

    @IBAction func deleteAction(button: UIButton) {
        // invoke protocol method
        delegate?.draggableCellDeleteButtonTapped?(self)
    }
    
    // MARK: UIGestureRecognizerDelegate
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer!, shouldRequireFailureOfGestureRecognizer otherGestureRecognizer: UIGestureRecognizer!) -> Bool {
        return !editing;
    }

}
