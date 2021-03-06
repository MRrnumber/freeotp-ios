//
// FreeOTP
//
// Authors: Nathaniel McCallum <npmccallum@redhat.com>
//
// Copyright (C) 2015  Nathaniel McCallum, Red Hat
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import UIKit

class TokensViewController : UICollectionViewController, UICollectionViewDelegateFlowLayout, UIPopoverPresentationControllerDelegate {
    private var lastPath: NSIndexPath? = nil
    private var store = TokenStore()

    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return store.count
    }

    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("token", forIndexPath: indexPath) as! TokenCell

        if let token = store.load(indexPath.row) {
            cell.state = nil

            ImageDownloader(cell.image.bounds.size).fromURI(token.image, completion: {
                (image: UIImage) -> Void in
                UIView.animateWithDuration(0.3, animations: {
                    cell.image.image = image
                })
            })

            cell.lock.hidden = !token.locked
            cell.outer.hidden = token.kind != .TOTP
            cell.issuer.text = token.issuer
            cell.label.text = token.label
            cell.edit.token = token
            cell.share.token = token
        }

        return cell
    }

    func popoverPresentationControllerDidDismissPopover(popoverPresentationController: UIPopoverPresentationController) {
        collectionView?.reloadData()
    }

    private func next<T: UIViewController>(name: String, sender: AnyObject, dir: UIPopoverArrowDirection) -> T {
        switch UI_USER_INTERFACE_IDIOM() {
        case .Pad:
            let vc = storyboard!.instantiateViewControllerWithIdentifier(name + "Nav") as! UINavigationController

            vc.modalPresentationStyle = .Popover
            vc.popoverPresentationController?.delegate = self
            vc.popoverPresentationController?.permittedArrowDirections = dir

            switch sender {
            case let b as UIBarButtonItem:
                vc.popoverPresentationController?.barButtonItem = b
            case let v as UIView:
                vc.popoverPresentationController?.sourceView = v
                vc.popoverPresentationController?.sourceRect = v.bounds
            default:
                break
            }

            presentedViewController?.dismissViewControllerAnimated(true, completion: nil)
            presentViewController(vc, animated: true, completion: nil)
            return vc.topViewController! as! T

        default:
            let ret = storyboard?.instantiateViewControllerWithIdentifier(name) as! T
            navigationController?.pushViewController(ret, animated: true)
            return ret
        }
    }

    @IBAction func addClicked(sender: UIBarButtonItem) {
        let vc: UIViewController = self.next("add", sender: sender, dir: [.Up, .Down])
        vc.preferredContentSize = CGSize(
            width: UIScreen.mainScreen().bounds.width / 2,
            height: vc.preferredContentSize.height
        )
    }

    @IBAction func scanClicked(sender: UIBarButtonItem) {
        let vc: UIViewController = self.next("scan", sender: sender, dir: [.Up, .Down])
        vc.preferredContentSize = CGSize(
            width: UIScreen.mainScreen().bounds.width / 2,
            height: vc.preferredContentSize.height
        )
    }

    @IBAction func editClicked(sender: TokenButton) {
        let evc: EditViewController = self.next("edit", sender: sender, dir: [.Left, .Right])
        evc.token = sender.token
    }

    @IBAction func shareClicked(sender: TokenButton) {
        let svc: ShareViewController = self.next("share", sender: sender, dir: [.Left, .Right])
        svc.token = sender.token
    }

    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        collectionView.deselectItemAtIndexPath(indexPath, animated: true)

        if let cell = collectionView.cellForItemAtIndexPath(indexPath) as! TokenCell? {
            if let token = store.load(indexPath.row) {
                cell.state = token.codes
            }
        }
    }

    override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
        collectionView?.performBatchUpdates(nil, completion: nil)
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        var numCols: CGFloat = 1

        let o = UIApplication.sharedApplication().statusBarOrientation
        if o == .LandscapeLeft || o == .LandscapeRight {
            numCols++
        }

        if UI_USER_INTERFACE_IDIOM() == .Pad {
            numCols++
        }

        let width = (collectionViewLayout as! UICollectionViewFlowLayout).columnWidth(collectionView, numCols: numCols)
        return CGSizeMake(width, width / 3.25);
    }

    func handleLongPress(gestureRecognizer:UIGestureRecognizer) {
        // Get the current index path.
        let p = gestureRecognizer.locationInView(collectionView)
        let currPath = collectionView?.indexPathForItemAtPoint(p)

        switch gestureRecognizer.state {
        case .Began:
            if currPath == nil { return }

            lastPath = currPath
            if let cell = collectionView?.cellForItemAtIndexPath(currPath!) {
                // Animate to the "lifted" state.
                UIView.animateWithDuration(0.3, animations: {
                    cell.transform = CGAffineTransformMakeScale(1.1, 1.1)
                    self.collectionView?.bringSubviewToFront(cell)
                })
            }

            return

        case .Changed:
            if currPath == nil { return }
            if lastPath == nil { return }

            let cell = collectionView?.cellForItemAtIndexPath(lastPath!)
            if cell == nil { return }

            if lastPath!.row != currPath!.row {
                // Move the display.
                collectionView?.moveItemAtIndexPath(lastPath!, toIndexPath: currPath!)

                // Scroll the display to handle moving tokens up or down.
                if lastPath!.row < currPath!.row {
                    collectionView?.scrollToItemAtIndexPath(currPath!, atScrollPosition: .Top, animated: true)
                } else {
                    collectionView?.scrollToItemAtIndexPath(currPath!, atScrollPosition: .Bottom, animated: true)
                }

                // Write changes.
                store.move(lastPath!.row, to: currPath!.row)

                // Reset state.
                cell!.transform = CGAffineTransformMakeScale(1.1, 1.1); // Moving the token resets the size...
                collectionView?.bringSubviewToFront(cell!) // ... and Z index.
                lastPath = currPath!;
            }

            cell!.center = gestureRecognizer.locationInView(collectionView)
            return

        case .Ended:
            if lastPath == nil { break }

            // Animate back to the original state, but in the new location.
            if let cell = collectionView?.cellForItemAtIndexPath(lastPath!) {
                UIView.animateWithDuration(0.3, animations: {
                    let l = self.collectionView?.collectionViewLayout
                    cell.center = l!.layoutAttributesForItemAtIndexPath(self.lastPath!)!.center
                    cell.transform = CGAffineTransformMakeScale(1.0, 1.0);
                }, completion: { (Bool) -> Void in
                    self.lastPath = nil
                })
            }

            collectionView?.reloadData()

        default:
            collectionView?.reloadData()
        }
    }

    @IBAction func unwindToTokens(sender: UIStoryboardSegue) {
        collectionView?.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup collection view.
        collectionView?.allowsSelection = true;
        collectionView?.allowsMultipleSelection = false;

        // Setup gesture.
        let lpg = UILongPressGestureRecognizer(target: self, action: "handleLongPress:")
        lpg.minimumPressDuration = 0.5
        collectionView?.addGestureRecognizer(lpg)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        collectionView?.reloadData()
    }
}
