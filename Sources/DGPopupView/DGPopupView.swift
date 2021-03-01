//
//  DGPopupView.swift
//
//  Depends on DGKeyboardScrollHandler if you want it
//   to pop up inside a scroll view and respond to keyboard showing up
//
//  Created by Daniel Cohen Gindi on 10/31/12.
//  Copyright (c) 2012 danielgindi@gmail.com. All rights reserved.
//
//  https://github.com/danielgindi/DGPopupView
//
//  The MIT License (MIT)
//
//  Copyright (c) 2014 Daniel Cohen Gindi (danielgindi@gmail.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation
import UIKit

public protocol DGPopupViewDelegate: AnyObject
{
    func popupViewDidPopup(_ popupView: DGPopupView?)
    func popupViewDidPopdown(_ popupView: DGPopupView?)
}

open class DGPopupView: UIView, UIGestureRecognizerDelegate, CAAnimationDelegate
{
    private weak var currentParentView: UIView? = nil
    private var popupOverlayView: UIButton? = nil
    private var popupPreviousScrollTouchPoint: CGPoint? = nil
    private var inAnimation: Animation = .scaleIn
    private var showNextAfterPopdown: Bool = false
    
    private static var s_PopupView_Popups: [[String: Any?]] = []
    
    open var hasOverlay = true
    open var popdownAnimation: Animation = .automatic
    open var closesFromOverlay = true
    open var considerSafeAreaInsets = true
    
    /** will create a scrollview that fills the parent - and popup inside it */
    open var wrapInScrollView = false
    
    /** the scrollView the was created if `wrappInScrollView` was specified */
    private(set) open var scrollViewWrapper: UIScrollView?
    
    open var overlayColor: UIColor?
    open weak var popupDelegate: DGPopupViewDelegate?
    
    open var didPopupBlock: (() -> Void)?
    open var didPopdownBlock: (() -> Void)?
    
    /**
     affects the auto-calculated popup position. { 0.5, 0.5 } means centered.
     @default: { 0.5, 0.5 }
     */
    open var popupRelativePosition = CGPoint(x: 0.5, y: 0.5)
    
    // MARK: - Init
    
    @discardableResult
    open class func popupFromXib() -> Self?
    {
        guard let views = Bundle.main.loadNibNamed(
                String(describing: self),
                owner: nil, options: nil)
        else { return nil }
        
        for view in views
        {
            guard let view = view as? Self else { continue }
            return view
        }
        
        return nil
    }
    
    public override init(frame: CGRect)
    {
        super.init(frame: frame)
        initialize()
    }
    
    public required init?(coder: NSCoder)
    {
        super.init(coder: coder)
        initialize()
    }
    
    private func initialize()
    {
        if #available(iOS 13.0, *)
        {
            overlayColor = UIColor.init(dynamicProvider: { traitCollection in
                if (traitCollection.userInterfaceStyle == .dark)
                {
                    return UIColor(white: 1.0, alpha: 0.3)
                }
                else
                {
                    return UIColor(white: 0.0, alpha: 0.6)
                }
            })
        }
        else
        {
            overlayColor = UIColor(white: 0.0, alpha: 0.6)
        }
    }
    
    // MARK: - UIView methods
    
    open override func willMove(toWindow newWindow: UIWindow?)
    {
        if newWindow == nil
        {
            removePopupFromCache()
        }
    }
    
    // MARK: - Public methods
    
    open func calculatePopupPosition(in frame: CGRect) -> CGRect
    {
        var popupFrame = self.frame
        popupFrame.origin.x = frame.origin.x + (frame.size.width - popupFrame.size.width) * popupRelativePosition.x
        popupFrame.origin.y = frame.origin.y + (frame.size.height - popupFrame.size.height) * popupRelativePosition.y
        return popupFrame
    }
    
    @discardableResult
    open func popup(from parentView: UIView, popupFrame: CGRect = .null, animation: Animation = .automatic, now: Bool = false) -> Any?
    {
        var parentView = parentView
        var animation = animation
        
        showNextAfterPopdown = true
        
        if !now
        {
            if self.currentPopup() != self
            {
                self.addNextPopup(fromView: parentView, frame: popupFrame, animation: animation)
            }
            
            if self.currentPopup() != self
            {
                return self
                
            }
        }
        
        currentParentView = parentView
        
        if animation == .automatic
        {
            animation = .scaleIn
        }
        
        inAnimation = animation
        
        let availableFrame = parentView.bounds
        var availableFrameForPopup = availableFrame
        
        if considerSafeAreaInsets
        {
            availableFrameForPopup =
                availableFrameForPopup.inset(by: parentView.safeAreaInsets)
        }
        
        if self.hasOverlay
        {
            // Set up overlay
            let popupOverlayView = UIButton(frame: availableFrame)
            self.popupOverlayView = popupOverlayView
            
            popupOverlayView.backgroundColor = overlayColor
            parentView.addSubview(popupOverlayView)
            
            if closesFromOverlay
            {
                popupOverlayView.addTarget(
                    self,
                    action: #selector(popupOverlayTouchedUpInside(_:)),
                    for: .touchUpInside)
            }
        }
        
        var popupFrame = popupFrame
        
        // Set up popup's frame
        if popupFrame.isNull
        {
            popupFrame = self.calculatePopupPosition(in: availableFrameForPopup)
        }
        
        // Set up scrollview
        if wrapInScrollView
        {
            let scrollView = UIScrollView(frame: availableFrame)
            self.scrollViewWrapper = scrollView
            
            scrollView.contentSize = CGSize(
                width: scrollView.contentSize.width,
                height: popupFrame.origin.y + popupFrame.size.height)
            
            let recognizer = UITapGestureRecognizer(
                target: self,
                action: #selector(popupOverlayTapRecognized(_:)))
            
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            scrollView.addGestureRecognizer(recognizer)
            
            parentView.addSubview(scrollView)
            
            parentView = scrollView
        }
        
        let easeOut = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        
        if animation != .none
        {
            if let popupOverlayView = popupOverlayView
            {
                // Set up animation for overlay
                let overlayAnimation = CABasicAnimation(keyPath: "opacity")
                overlayAnimation.duration = 0.3
                overlayAnimation.timingFunction = easeOut
                overlayAnimation.fromValue = 0.0
                overlayAnimation.toValue = popupOverlayView.layer.opacity
                
                popupOverlayView.layer.add(overlayAnimation, forKey: "popup")
            }
        }
        
        if animation == .scaleIn
        {
            // Set up popup
            self.frame = popupFrame
            parentView.addSubview(self)
            
            // Set up animation for popup
            
            let popupAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
            popupAnimation.duration = 0.15
            popupAnimation.values = [0.001, 1.0]
            popupAnimation.keyTimes = [0.0, 1.0]
            popupAnimation.timingFunctions = [easeOut]
            popupAnimation.fillMode = .both
            popupAnimation.delegate = self
            popupAnimation.isRemovedOnCompletion = false // So we can keep track of it in animationDidStop:finished:
            
            self.layer.transform = CATransform3DIdentity
            self.layer.add(popupAnimation, forKey: "popup")
        }
        else if animation == .fadeIn
        {
            // Set up popup
            self.frame = popupFrame
            parentView.addSubview(self)
            
            // Set up animation for popup
            
            let alpha:CGFloat = self.alpha
            self.alpha = 0.0
            
            UIView.animate(withDuration: 0.4, delay: 0.0, options: .curveEaseOut, animations: {
                self.alpha = alpha
            }, completion: { _ in
                self.finishPopup()
            })
        }
        else if animation == .popup
        {
            // Set up popup
            self.frame = popupFrame
            parentView.addSubview(self)
            
            // Set up animation for popup
            
            let overShoot = CAMediaTimingFunction(controlPoints: 0.25, 0.0, 0.4, 1.6)
            
            let popupAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
            popupAnimation.duration = 0.4
            popupAnimation.values = [0.001, 1.0, 0.7, 1.0]
            popupAnimation.keyTimes = [0.0, 0.4, 0.7, 1.0]
            popupAnimation.timingFunctions = [overShoot, easeOut, overShoot]
            popupAnimation.fillMode = .both
            popupAnimation.delegate = self
            popupAnimation.isRemovedOnCompletion = false // So we can keep track of it in animationDidStop:finished:
            
            self.layer.transform = CATransform3DIdentity
            self.layer.add(popupAnimation, forKey: "popup")
        }
        else if animation == .topBottom ||
                    animation == .bottomTop
        {
            // Set up popup
            self.frame = popupFrame
            parentView.addSubview(self)
            
            // Set up animation for popup
            
            var fromFrame = self.frame
            let toFrame = self.frame
            fromFrame.origin.y =
                animation == .topBottom
                ? (-fromFrame.size.height)
                : (self.superview?.bounds.size.height ?? 0.0)
            self.frame = fromFrame
            
            UIView.animate(withDuration: 0.4, delay: 0.0, options: .curveEaseOut, animations: {
                self.frame = toFrame
            }, completion: { _ in 
                self.finishPopup()
            })
        }
        else // .none
        {
            // Set up popup
            self.frame = popupFrame
            parentView.addSubview(self)
            
            self.finishPopup()
        }
        
        return self
    }
    
    @discardableResult
    open func popdown(showNext: Bool = true, animated: Bool = true) -> Self
    {
        showNextAfterPopdown = showNext
        
        if superview == nil
        {
            if isInCache()
            {
                removePopupFromCache()

                if showNextAfterPopdown
                {
                    dequeueNext()
                }
            }

            return self
        }

        var animationType = popdownAnimation
        
        if animationType == .automatic
        {
            animationType = inAnimation
        }
        
        if !animated
        {
            animationType = .none
        }

        if animationType != .none
        {
            if let popupOverlayView = popupOverlayView
            {
                let easeOut = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)

                // Set up animation for overlay
                let overlayAnimation = CABasicAnimation(keyPath: "opacity")
                overlayAnimation.duration = 0.3
                overlayAnimation.timingFunction = easeOut
                overlayAnimation.fromValue = popupOverlayView.layer.opacity
                overlayAnimation.toValue = 0.0

                popupOverlayView.layer.opacity = 0.0
                popupOverlayView.layer.add(overlayAnimation, forKey: "popdown")
            }
        }

        if animationType == .scaleIn
        {
            let easeOut = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)

            // Set up animation for popup

            let popdownAnimation = CABasicAnimation(keyPath: "transform")
            popdownAnimation.fromValue = CATransform3DIdentity
            popdownAnimation.toValue = CATransform3DMakeScale(0.001, 0.0, 1.0)
            popdownAnimation.duration = 0.2
            popdownAnimation.timingFunction = easeOut
            popdownAnimation.fillMode = .both
            popdownAnimation.delegate = self
            popdownAnimation.isRemovedOnCompletion = false // So we can keep track of it in animationDidStop:finished:

            self.layer.transform = CATransform3DMakeScale(0.0, 0.0, 1.0)
            self.layer.add(popdownAnimation, forKey: "popdown")
        }
        else if animationType == .fadeIn
        {
            // Set up animation for popup
            
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseInOut, animations: {
                self.alpha = 0.0
            }, completion: { _ in
                self.finishPopdown()
            })
        }
        else if animationType == .popup
        {
            // Set up animation for popup

            let overShoot = CAMediaTimingFunction(controlPoints: 0.15, -0.30, 0.88, 0.14)


            let popdownAnimation = CABasicAnimation(keyPath: "transform")
            popdownAnimation.fromValue = CATransform3DIdentity
            popdownAnimation.toValue = CATransform3DMakeScale(0.001, 0.001, 1.0)
            popdownAnimation.duration = 0.2
            popdownAnimation.timingFunction = overShoot
            popdownAnimation.fillMode = .both
            popdownAnimation.delegate = self
            popdownAnimation.isRemovedOnCompletion = false // So we can keep track of it in animationDidStop:finished:

            self.layer.transform = CATransform3DMakeScale(0.0, 0.0, 1.0)
            self.layer.add(popdownAnimation, forKey: "popdown")
        }
        else if animationType == .topBottom ||
                    animationType == .bottomTop
        {
            // Set up animation for popup

            let fromFrame = self.frame
            var toFrame = self.frame
            toFrame.origin.y =
                animationType == .topBottom
                ? (-toFrame.size.height)
                : (self.superview?.bounds.size.height ?? 0.0)
            self.frame = fromFrame
            
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseOut, animations: {
                self.frame = toFrame
            }, completion: { _ in
                self.finishPopdown()
            })
        }
        else // .none
        {
            self.finishPopdown()
        }
        return self
    }

    @objc func popupOverlayTouchedUpInside(_ sender: Any?)
    {
        let _ = popdown()
    }

    @objc func popupOverlayTapRecognized(_ recognizer: UITapGestureRecognizer?)
    {
        if bounds.contains(recognizer?.location(in: self) ?? CGPoint.zero)
        {
            return
        }

        let _ = popdown()
    }
    
    /** this method does nothing and is called when popup is showing and done animating */
    open func didFinishPopup()
    {
        // for subclassing
    }
    
    /** this method does nothing and is called when popup is hidden and done animating */
    open func didFinishPopdown()
    {
        // for subclassing
    }
    
    // MARK: - Private methods
    
    private func finishPopup()
    {
        didFinishPopup()

        popupDelegate?.popupViewDidPopup(self)
    
        if let didPopupBlock = didPopupBlock
        {
            didPopupBlock()
        }
    }

    private func finishPopdown()
    {
        popupOverlayView?.removeFromSuperview()
        popupOverlayView = nil
        scrollViewWrapper?.removeFromSuperview()
        scrollViewWrapper = nil
        removeFromSuperview()
        currentParentView = nil
        
        popupDelegate?.popupViewDidPopdown(self)
        
        if let didPopdownBlock = didPopdownBlock
        {
            didPopdownBlock()
        }

        if isInCache()
        {
            removePopupFromCache()
        }

        if showNextAfterPopdown
        {
            self.dequeueNext()
        }

        didFinishPopdown()
    }
    
    private func dequeueNext()
    {
        guard let nextOne = self.currentPopupCache() else { return }
        
        let popup = nextOne["popup"] as? DGPopupView
        if popup?.superview != nil &&
            popup?.currentParentView == nextOne["fromView"] as? UIView
        {
            // Already popped up
            return
        }
    
        let _ = (nextOne["popup"] as? DGPopupView)?
            .popup(from: nextOne["fromView"] as! UIView,
                   popupFrame: nextOne["frame"] as? CGRect ?? .null,
                   animation: nextOne["animation"] as? Animation ?? .automatic,
                   now: false
            )
    }
    
    private func addNextPopup(
        fromView: UIView,
        frame: CGRect,
        animation: Animation)
    {
        DGPopupView.s_PopupView_Popups.append([
            "popup": self,
            "fromView": fromView,
            "frame": frame,
            "animation": animation
        ])
    }

    private func removePopupFromCache()
    {
        for i in (0..<DGPopupView.s_PopupView_Popups.count).reversed()
        {
            let item = DGPopupView.s_PopupView_Popups[i]
            if item["popup"] as? DGPopupView == self
            {
                DGPopupView.s_PopupView_Popups.remove(at: i)
            }
        }
    }

    private func isInCache() -> Bool
    {
        return DGPopupView.s_PopupView_Popups
            .contains(where: { $0["popup"] as? DGPopupView == self })
    }

    private func currentPopup() -> DGPopupView?
    {
        return currentPopupCache()?["popup"] as? DGPopupView
    }

    private func currentPopupCache() -> [String: Any?]?
    {
        return DGPopupView.s_PopupView_Popups.first
    }
    
    // MARK: - CAAnimationDelegate
    
    open func animationDidStop(_ anim: CAAnimation, finished flag: Bool)
    {
        if anim == self.layer.animation(forKey: "popup")
        {
            self.layer.removeAnimation(forKey: "popup")
            self.finishPopup()
        }
        else if anim == self.layer.animation(forKey: "popdown")
        {
            self.layer.removeAnimation(forKey: "popdown")
            self.finishPopdown()
        }
    }
    
    // MaRK: - UIGestureRecognizerDelegate
    
    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    {
        return true
    }
    
    // MARK: - Types
    
    public enum Animation : Int
    {
        case none
        case automatic
        case popup
        case scaleIn
        case fadeIn
        case topBottom
        case bottomTop
    }
}
