//
//  DGPopupView.m
//  DGPopupView
//
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

#import "DGPopupView.h"
#import <QuartzCore/QuartzCore.h>

@interface DGPopupView () <UIGestureRecognizerDelegate>
{
    UIView *currentParentView;
    UIButton *popupOverlayView;
    UIScrollView *_scrollView;
    CGPoint popupPreviousScrollTouchPoint;
    DGPopupViewAnimationType inAnimation;
    BOOL showNextAfterPopdown;
    UITapGestureRecognizer *scrollViewTapGestureRecognizer;
}
@end

@implementation DGPopupView

static NSMutableArray *s_PopupView_Popups = nil;
static NSString *s_DGPopupView_syncObject = @"DGPopupView_syncObject";

- (BOOL)isThereACurrentPopup
{
    return s_PopupView_Popups.count;
}

- (void)addNextPopup:(DGPopupView*)popupView fromView:(UIView*)fromView withFrame:(CGRect)frame animation:(DGPopupViewAnimationType)animationType
{
    @synchronized(s_DGPopupView_syncObject)
    {
        if (!s_PopupView_Popups)
        {
            s_PopupView_Popups = [[NSMutableArray alloc] init];
        }
        [s_PopupView_Popups addObject:@{
                                        @"popup": popupView,
                                        @"fromView": fromView,
                                        @"frame": [NSValue valueWithCGRect:frame],
                                        @"animation": @(animationType)
                                        }];
    }
}

- (void)removePopupFromCache:(DGPopupView*)popup
{
    @synchronized(s_DGPopupView_syncObject)
    {
        NSDictionary *item;
        for (int j=0; j<s_PopupView_Popups.count; j++)
        {
            item = s_PopupView_Popups[j];
            if (item[@"popup"] == popup)
            {
                [s_PopupView_Popups removeObject:item];
                j--;
            }
        }
    }
}

- (BOOL)hasPopupInCache:(DGPopupView *)popup
{
    @synchronized(s_DGPopupView_syncObject)
    {
        NSDictionary *item;
        for (int j=0; j<s_PopupView_Popups.count; j++)
        {
            item = s_PopupView_Popups[j];
            if (item[@"popup"] == popup)
            {
                return YES;
            }
        }
    }
    return NO;
}

- (DGPopupView *)currentPopup
{
    @synchronized(s_DGPopupView_syncObject)
    {
        if (!s_PopupView_Popups.count) return nil;
        return s_PopupView_Popups[0][@"popup"];
    }
}

- (NSDictionary *)currentPopupCache
{
    @synchronized(s_DGPopupView_syncObject)
    {
        if (!s_PopupView_Popups.count) return nil;
        return s_PopupView_Popups[0];
    }
}

+ (instancetype)popupFromXib
{
    NSArray *views = [NSBundle.mainBundle loadNibNamed:NSStringFromClass(self) owner:nil options:nil];
    for (NSObject *view in views)
    {
        if ([view isKindOfClass:self])
        {
            return (id)view;
        }
    }
    return nil;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self DGPopupView_initialize];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self DGPopupView_initialize];
    }
    return self;
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    if (newWindow == nil)
    {
        [self removePopupFromCache:self];
    }
}

- (void)DGPopupView_initialize
{
    _hasOverlay = YES;
    _closesFromOverlay = YES;
    _popdownAnimation = DGPopupViewAnimationTypeAutomatic;
    _overlayColor = [UIColor colorWithWhite:0.f alpha:.6f];
}

- (id)popupFromView:(UIView *)parentView
{
    return [self popupFromView:parentView withPopupFrame:CGRectNull animation:DGPopupViewAnimationTypeScaleIn now:NO];
}

- (id)popupFromView:(UIView *)parentView now:(BOOL)now
{
    return [self popupFromView:parentView withPopupFrame:CGRectNull animation:DGPopupViewAnimationTypeScaleIn now:now];
}

- (id)popupFromView:(UIView *)parentView withPopupFrame:(CGRect)popupFrame
{
    return [self popupFromView:parentView withPopupFrame:popupFrame animation:DGPopupViewAnimationTypeScaleIn now:NO];
}

- (id)popupFromView:(UIView* )parentView withPopupFrame:(CGRect)popupFrame animation:(DGPopupViewAnimationType)animation
{
    return [self popupFromView:parentView withPopupFrame:popupFrame animation:animation now:NO];
}

- (id)popupFromView:(UIView *)parentView animation:(DGPopupViewAnimationType)animation
{
    return [self popupFromView:parentView withPopupFrame:CGRectNull animation:animation now:NO];
}

- (id)popupFromView:(UIView *)parentView animation:(DGPopupViewAnimationType)animation now:(BOOL)now
{
    return [self popupFromView:parentView withPopupFrame:CGRectNull animation:animation now:now];
}

- (id)popupFromView:(UIView *)parentView withPopupFrame:(CGRect)popupFrame animation:(DGPopupViewAnimationType)animation now:(BOOL)now
{
    showNextAfterPopdown = YES;
    
    if (!now)
    {
        if (self.currentPopup != self)
        {
            [self addNextPopup:self fromView:parentView withFrame:popupFrame animation:animation];
        }
        if (self.currentPopup != self) return self;
    }
    
    currentParentView = parentView;
    
    inAnimation = animation;
    
    CGRect availableFrame = parentView.bounds;
    
    if (self.hasOverlay)
    {
        // Set up overlay
        popupOverlayView = [[UIButton alloc] initWithFrame:availableFrame];
        popupOverlayView.backgroundColor = _overlayColor;
        [parentView addSubview:popupOverlayView];
        
        if (_closesFromOverlay)
        {
            [popupOverlayView addTarget:self action:@selector(popupOverlayTouchedUpInside:) forControlEvents:UIControlEventTouchUpInside];
        }
    }
    
    // Set up popup's frame
    if (CGRectIsNull(popupFrame))
    {
        popupFrame = [self calculatePopupPositionInsideFrame:availableFrame];
    }
    
    // Set up scrollview
    if (_wrapInScrollView)
    {
        _scrollView = [[UIScrollView alloc] initWithFrame:availableFrame];
        _scrollView.contentSize = CGSizeMake(_scrollView.contentSize.width, popupFrame.origin.y + popupFrame.size.height);
        
        scrollViewTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(popupOverlayTapRecognized:)];
        scrollViewTapGestureRecognizer.cancelsTouchesInView = NO;
        scrollViewTapGestureRecognizer.delegate = self;
        [_scrollView addGestureRecognizer:scrollViewTapGestureRecognizer];
        
        [parentView addSubview:_scrollView];
        
        parentView = _scrollView;
    }
    
    CAMediaTimingFunction *easeOut = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    
    if (animation != DGPopupViewAnimationTypeNone)
    {
        if (popupOverlayView)
        {
            // Set up animation for overlay
            CABasicAnimation *overlayAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
            overlayAnimation.duration = 0.3f;
            overlayAnimation.timingFunction = easeOut;
            overlayAnimation.fromValue = @0.f;
            overlayAnimation.toValue = @(popupOverlayView.layer.opacity);
            
            [popupOverlayView.layer addAnimation:overlayAnimation forKey:@"popup"];
        }
    }
    
    if (animation == DGPopupViewAnimationTypeScaleIn)
    {
        // Set up popup
        self.frame = popupFrame;
        [parentView addSubview:self];
        
        // Set up animation for popup
        
        CAKeyframeAnimation *popupAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        popupAnimation.duration = .15f;
        popupAnimation.values = @[@.001f, @1.f];
        popupAnimation.keyTimes = @[@0.f, @1.f];
        popupAnimation.timingFunctions = @[easeOut];
        popupAnimation.fillMode = kCAFillModeBoth;
        popupAnimation.removedOnCompletion = NO; // So we can keep track of it in animationDidStop:finished:
        
        self.layer.transform = CATransform3DIdentity;
        [self.layer addAnimation:popupAnimation forKey:@"popup"];
    }
    else if (animation == DGPopupViewAnimationTypeFadeIn)
    {
        // Set up popup
        self.frame = popupFrame;
        [parentView addSubview:self];
        
        // Set up animation for popup
        
        CGFloat alpha = self.alpha;
        self.alpha = 0.f;
        
        [UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.alpha = alpha;
        } completion:^(BOOL finished) {
            [self finishPopup];
        }];
    }
    else if (animation == DGPopupViewAnimationTypePopup)
    {
        // Set up popup
        self.frame = popupFrame;
        [parentView addSubview:self];
        
        // Set up animation for popup
        
        CAMediaTimingFunction *overShoot = [CAMediaTimingFunction functionWithControlPoints:0.25 // c1x
                                                                                           :0.0  // c1y
                                                                                           :0.4  // c2x
                                                                                           :1.6];// c2y
        
        CAKeyframeAnimation *popupAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        popupAnimation.duration = .4f;
        popupAnimation.values = @[@.001f, @1.f, @0.7f, @1.f];
        popupAnimation.keyTimes = @[@0.f, @0.4f, @0.7f, @1.f];
        popupAnimation.timingFunctions = @[overShoot, easeOut, overShoot];
        popupAnimation.fillMode = kCAFillModeBoth;
        popupAnimation.removedOnCompletion = NO; // So we can keep track of it in animationDidStop:finished:
        
        self.layer.transform = CATransform3DIdentity;
        [self.layer addAnimation:popupAnimation forKey:@"popup"];
    }
    else if (animation == DGPopupViewAnimationTypeTopBottom ||
             animation == DGPopupViewAnimationTypeBottomTop)
    {
        // Set up popup
        self.frame = popupFrame;
        [parentView addSubview:self];
        
        // Set up animation for popup
        
        CGRect fromFrame = self.frame;
        CGRect toFrame = self.frame;
        fromFrame.origin.y = animation == DGPopupViewAnimationTypeTopBottom ? (-fromFrame.size.height) : (self.superview.bounds.size.height);
        self.frame = fromFrame;
        
        [UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.frame = toFrame;
        } completion:^(BOOL finished) {
            [self finishPopup];
        }];
    }
    else // if (animation == DGPopupViewAnimationTypeNone)
    {
        
        // Set up popup
        self.frame = popupFrame;
        [parentView addSubview:self];
        
        [self finishPopup];
        
    }
    
    return self;
}

- (CGRect)calculatePopupPositionInsideFrame:(CGRect)parentFrame
{
    CGRect popupFrame = self.frame;
    popupFrame.origin.x = (parentFrame.size.width - popupFrame.size.width) / 2.f;
    popupFrame.origin.y = (parentFrame.size.height - popupFrame.size.height) / 2.f;
    return popupFrame;
}

- (id)popdown
{
    return [self popdownAnimated:YES];
}

- (id)popdownAnimated:(BOOL)animated
{
    return [self popdownShowNext:YES animated:YES];
}

- (id)popdownShowNext:(BOOL)showNext animated:(BOOL)animated
{
    showNextAfterPopdown = showNext;
    
    if (!self.superview)
    {
        if ([self hasPopupInCache:self])
        {
            [self removePopupFromCache:self];
            
            if (showNextAfterPopdown)
            {
                NSDictionary *nextOne = self.currentPopupCache;
                if (nextOne)
                {
                    [nextOne[@"popup"] popupFromView:nextOne[@"fromView"] withPopupFrame:[((NSValue*)nextOne[@"frame"]) CGRectValue] animation:(DGPopupViewAnimationType)[nextOne[@"animation"] intValue] now:NO];
                }
            }
        }
        
        return self;
    }
    
    DGPopupViewAnimationType animationType = _popdownAnimation;
    if (animationType == DGPopupViewAnimationTypeAutomatic)
    {
        animationType = inAnimation;
    }
    if (!animated)
    {
        animationType = DGPopupViewAnimationTypeNone;
    }
    
    if (animationType != DGPopupViewAnimationTypeNone)
    {
        if (popupOverlayView)
        {
            CAMediaTimingFunction *easeOut = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            
            // Set up animation for overlay
            CABasicAnimation *overlayAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
            overlayAnimation.duration = 0.3f;
            overlayAnimation.timingFunction = easeOut;
            overlayAnimation.fromValue = @(popupOverlayView.layer.opacity);
            overlayAnimation.toValue = @0.f;
            
            popupOverlayView.layer.opacity = 0.f;
            [popupOverlayView.layer addAnimation:overlayAnimation forKey:@"popdown"];
        }
    }
    
    if (animationType == DGPopupViewAnimationTypeScaleIn)
    {
        CAMediaTimingFunction *easeOut = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        
        // Set up animation for popup
        
        CABasicAnimation* popdownAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
        popdownAnimation.fromValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
        popdownAnimation.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(0.001, 0.f, 1.0)];
        popdownAnimation.duration = .2f;
        popdownAnimation.timingFunction = easeOut;
        popdownAnimation.fillMode = kCAFillModeBoth;
        popdownAnimation.removedOnCompletion = NO; // So we can keep track of it in animationDidStop:finished:
        
        self.layer.transform = CATransform3DMakeScale(0.f, 0.f, 1.f);
        [self.layer addAnimation:popdownAnimation forKey:@"popdown"];
    }
    else if (animationType == DGPopupViewAnimationTypeFadeIn)
    {
        // Set up animation for popup
        
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.alpha = 0.f;
        } completion:^(BOOL finished) {
            
            [self finishPopdown];
            
        }];
    }
    else if (animationType == DGPopupViewAnimationTypePopup)
    {
        // Set up animation for popup
        
        CAMediaTimingFunction *overShoot = [CAMediaTimingFunction functionWithControlPoints:0.15:-0.30:0.88:0.14];
        
        
        CABasicAnimation* popdownAnimation = [CABasicAnimation animationWithKeyPath:@"transform"];
        popdownAnimation.fromValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
        popdownAnimation.toValue = [NSValue valueWithCATransform3D:CATransform3DMakeScale(0.001, 0.001, 1.0)];
        popdownAnimation.duration = .2f;
        popdownAnimation.timingFunction = overShoot;
        popdownAnimation.fillMode = kCAFillModeBoth;
        popdownAnimation.removedOnCompletion = NO; // So we can keep track of it in animationDidStop:finished:
        
        self.layer.transform = CATransform3DMakeScale(0.f, 0.f, 1.f);
        [self.layer addAnimation:popdownAnimation forKey:@"popdown"];
    }
    else if (animationType == DGPopupViewAnimationTypeTopBottom ||
             animationType == DGPopupViewAnimationTypeBottomTop)
    {
        // Set up animation for popup
        
        CGRect fromFrame = self.frame;
        CGRect toFrame = self.frame;
        toFrame.origin.y = animationType == DGPopupViewAnimationTypeTopBottom ? (-toFrame.size.height) : (self.superview.bounds.size.height);
        self.frame = fromFrame;
        
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.frame = toFrame;
        } completion:^(BOOL finished) {
            
            [self finishPopdown];
            
        }];
    }
    else // if (animationType == DGPopupViewAnimationTypeNone)
    {
        
        [self finishPopdown];
        
    }
    return self;
}

- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag
{
    if (theAnimation == [self.layer animationForKey:@"popup"])
    {
        [self.layer removeAnimationForKey:@"popup"];
        
        [self finishPopup];
    }
    else if (theAnimation == [self.layer animationForKey:@"popdown"])
    {
        [self.layer removeAnimationForKey:@"popdown"]; // Because of removedOnCompletion=NO
        
        [self finishPopdown];
    }
}

- (void)didFinishPopup
{
    
}

- (void)didFinishPopdown
{
    
}

- (void)finishPopup
{
    [self didFinishPopup];
    
    if ([_popupDelegate respondsToSelector:@selector(popupViewDidPopup:)])
    {
        [_popupDelegate popupViewDidPopup:self];
    }
    if (_didPopupBlock)
    {
        _didPopupBlock();
    }
}

- (void)finishPopdown
{
    [popupOverlayView removeFromSuperview];
    popupOverlayView = nil;
    [_scrollView removeFromSuperview];
    _scrollView = nil;
    [self removeFromSuperview];
    currentParentView = nil;
    if ([_popupDelegate respondsToSelector:@selector(popupViewDidPopdown:)])
    {
        [_popupDelegate popupViewDidPopdown:self];
    }
    if (_didPopdownBlock)
    {
        _didPopdownBlock();
    }
    
    if ([self hasPopupInCache:self])
    {
        [self removePopupFromCache:self];
    }
    
    if (showNextAfterPopdown)
    {
        NSDictionary *nextOne = self.currentPopupCache;
        if (nextOne)
        {
            DGPopupView *popup = nextOne[@"popup"];
            if (popup.superview && popup->currentParentView == nextOne[@"fromView"])
            {
                // Already popped up
                return;
            }
            [popup popupFromView:nextOne[@"fromView"] withPopupFrame:[((NSValue*)nextOne[@"frame"]) CGRectValue] animation:(DGPopupViewAnimationType)[nextOne[@"animation"] intValue] now:NO];
        }
    }
    
    [self didFinishPopdown];
}

- (void)popupOverlayTouchedUpInside:(id)sender
{
    [self popdown];
}

- (void)popupOverlayTapRecognized:(UITapGestureRecognizer *)recognizer
{
    if (CGRectContainsPoint(self.bounds, [recognizer locationInView:self]))
    {
        return;
    }
    
    [self popdown];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark - Accessors

- (UIScrollView *)scrollViewWrapper
{
    return _scrollView;
}

#pragma mark - Utilities

- (UIImage *)gradientImageSized:(CGSize)size colors:(NSArray *)colors locations:(NSArray *)locations vertical:(BOOL)vertical
{
    UIGraphicsBeginImageContextWithOptions(size, NO, UIScreen.mainScreen.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    NSUInteger locationsCount = locations.count;
    CGFloat *fLocations = locationsCount ? malloc(locations.count * sizeof(CGFloat)) : NULL;
    CGFloat *location = fLocations;
    if (locationsCount)
    {
        for (NSNumber *n in locations)
        {
            *location = [n floatValue];
            location++;
        }
    }
    
    NSMutableArray *colorsAray = [[NSMutableArray alloc] init];
    for (UIColor *color in colors)
    {
        [colorsAray addObject:(id)color.CGColor];
    }
    
    CGColorSpaceRef rgbColorspace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColors(rgbColorspace, (__bridge CFArrayRef)colorsAray, fLocations);
    
    CGContextDrawLinearGradient(context, gradient,
                                vertical?CGPointMake(0.f, 0.f):CGPointMake(0.f, 0.f),
                                vertical?CGPointMake(0.f, size.height):CGPointMake(size.width, 0.f), 0);
    
    if (fLocations)
    {
        free(fLocations);
    }
    
    CGGradientRelease(gradient);
    CGColorSpaceRelease(rgbColorspace);
    
    UIImage *gradientImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return gradientImage;
}

@end
