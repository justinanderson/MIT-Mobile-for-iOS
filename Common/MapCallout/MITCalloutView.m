#import "MITCalloutView.h"
#import "MITCalloutDefaultContentView.h"

NSInteger const MITCalloutPermittedArrowDirectionAny = MITCalloutArrowDirectionTop | MITCalloutArrowDirectionLeft | MITCalloutArrowDirectionBottom | MITCalloutArrowDirectionRight;

static CGSize const kMITCalloutViewDefaultArrowSize = {30,15};
static CGFloat const kMITCalloutViewDefaultCornerRadius = 10;
static CGFloat const kMITCalloutViewDefaultArrowOffset = 5.0;
static UIEdgeInsets const kMITCalloutViewDefaultInternalInsets = {5,5,5,5};
static UIEdgeInsets const kMITCalloutViewDefaultExternalInsets = {10,10,10,10};

@interface MITCalloutView ()

@property (nonatomic) MITCalloutArrowDirection currentArrowDirection;

@property (nonatomic) CGSize arrowSize;
@property (nonatomic) CGPoint controlPoint;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) CGFloat arrowOffset; // Distance from presentation rect to arrow
@property (nonatomic, readonly) CGRect framingRect;

@property (strong, nonatomic) CAShapeLayer *maskingShapeLayer;
@property (strong, nonatomic) CAShapeLayer *shadowShapeLayer;
@property (strong, nonatomic) UIBezierPath *maskingPath;

// Retain presentation values for reorienting when view changes
@property (nonatomic) CGRect presentationRect;
@property (weak, nonatomic) UIView *presentationView;
@property (weak, nonatomic) UIView *constrainingView;
@property (nonatomic, readonly) BOOL hasDefaultContentView;

@property (weak, nonatomic) NSLayoutConstraint *topContentConstraint;
@property (weak, nonatomic) NSLayoutConstraint *leftContentConstraint;
@property (weak, nonatomic) NSLayoutConstraint *bottomContentConstraint;
@property (weak, nonatomic) NSLayoutConstraint *rightContentConstraint;

@property (nonatomic) BOOL keepSizeWithinConstrainingView;
@property (nonatomic) CGSize contentViewMaxSize;
@property (nonatomic) CGFloat contentViewConstraintPaddingHorizontal;
@property (nonatomic) CGFloat contentViewConstraintPaddingVertical;

@end

@implementation MITCalloutView

@synthesize contentView = _contentView;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _arrowOffset = kMITCalloutViewDefaultArrowOffset;
        _arrowSize = kMITCalloutViewDefaultArrowSize;
        _cornerRadius = kMITCalloutViewDefaultCornerRadius;
        _internalInsets = kMITCalloutViewDefaultInternalInsets;
        _externalInsets = kMITCalloutViewDefaultExternalInsets;
        _shouldHighlightOnTouch = YES;
        _permittedArrowDirections = MITCalloutPermittedArrowDirectionAny;
        _contentViewConstraintPaddingHorizontal = 20;
        _contentViewConstraintPaddingVertical = 40;
        _keepSizeWithinConstrainingView = YES;
        self.backgroundColor = [UIColor whiteColor];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateLayout];
}

- (void)updateLayout {
    [self resizeAndPositionSubviews];
    [self drawPointerForControlPoint:self.controlPoint animated:NO];
}

#pragma mark - Layout

- (void)reorientPresentation {
    if (self.superview) {
        // Already in view hierarchy, reorient:
        [self presentFromRect:self.presentationRect inView:self.presentationView withConstrainingView:self.constrainingView];
    }
}

- (void)resizeAndPositionSubviews {
    
    CGFloat maxWidth, maxHeight;
    if (self.hasDefaultContentView) {
        MITCalloutViewDefaultContentView *contentView = (MITCalloutViewDefaultContentView *)self.contentView;
        CGSize contentSize = [contentView sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
        
        maxHeight = contentSize.height + self.internalInsets.top + self.internalInsets.bottom;
        maxWidth = contentSize.width + self.internalInsets.left + self.internalInsets.right;
    } else {
        // Save preferred size at time of set because constraints will resize
        maxHeight = self.contentViewPreferredSize.height + self.internalInsets.top + self.internalInsets.bottom;
        maxWidth = self.contentViewPreferredSize.width + self.internalInsets.left + self.internalInsets.right;
    }
    
    if (self.keepSizeWithinConstrainingView) {
        if (maxHeight > self.contentViewMaxSize.height) {
            maxHeight = self.contentViewMaxSize.height;
        }
        if (maxWidth > self.contentViewMaxSize.width) {
            maxWidth = self.contentViewMaxSize.width;
        }
    }
    
    switch (self.currentArrowDirection) {
        case MITCalloutArrowDirectionTop:
        case MITCalloutArrowDirectionBottom:
            maxHeight += self.arrowSize.height;
            if (maxWidth < [self minimumEdgeLength]) {
                maxWidth = [self minimumEdgeLength];
            }
            break;
        case MITCalloutArrowDirectionLeft:
        case MITCalloutArrowDirectionRight:
            maxWidth += self.arrowSize.height;
            if (maxHeight < [self minimumEdgeLength]) {
                maxHeight = [self minimumEdgeLength];
            }
            break;
        case MITCalloutArrowDirectionNone:
            break;
    }
    
    CGRect bounds = self.bounds;
    bounds.size.height = maxHeight;
    bounds.size.width = maxWidth;
    self.bounds = bounds;
    
    [self updateConstraintsForArrowDirection:self.currentArrowDirection];
}

- (void)updateConstraintsForArrowDirection:(MITCalloutArrowDirection)arrowDirection {
    
    CGFloat top = self.internalInsets.top;
    CGFloat left = self.internalInsets.left;
    CGFloat bottom = -self.internalInsets.bottom;
    CGFloat right = -self.internalInsets.right;
    
    switch (arrowDirection) {
        case MITCalloutArrowDirectionTop:
            top += self.arrowSize.height;
            break;
        case MITCalloutArrowDirectionLeft:
            left += self.arrowSize.height;
            break;
        case MITCalloutArrowDirectionBottom:
            bottom -= self.arrowSize.height;
            break;
        case MITCalloutArrowDirectionRight:
            right -= self.arrowSize.height;
            break;
        case MITCalloutArrowDirectionNone:
            break;
    }
    
    self.topContentConstraint.constant = top;
    self.leftContentConstraint.constant = left;
    self.bottomContentConstraint.constant = bottom;
    self.rightContentConstraint.constant = right;
}

#pragma mark - Pointer Drawing

/*
 Control Point is where the tip of the arrow should be in self.bounds coordinate system
 */

- (void)drawPointerForControlPoint:(CGPoint)controlPoint {
    [self drawPointerForControlPoint:controlPoint animated:NO];
}

- (void)drawPointerForControlPoint:(CGPoint)controlPoint animated:(BOOL)animated {
    CGSize arrowSize = self.arrowSize;
    CGFloat arrowWidth = arrowSize.width;
    CGFloat arrowHeight = arrowSize.height;
    CGFloat halfArrowWidth = arrowWidth / 2.0;
    
    CGRect framingRect = self.framingRect;
    CGFloat originX = CGRectGetMinX(framingRect);
    CGFloat originY = CGRectGetMinY(framingRect);
    CGFloat rightEdge = CGRectGetMaxX(framingRect);
    CGFloat bottomEdge = CGRectGetMaxY(framingRect);
    
    CGPoint topLeft = CGPointMake(originX, originY);
    CGPoint topRight = CGPointMake(rightEdge, originY);
    CGPoint lowerRight = CGPointMake(rightEdge, bottomEdge);
    CGPoint lowerLeft = CGPointMake(originX, bottomEdge);
    
    CGFloat arrowTipHeight = arrowHeight / 10;
    CGFloat arrowTipWidth = arrowWidth / 10;
    CGFloat arrowBaseBezierControlInset = arrowWidth / 10;
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    
    // Top left corner
    [path moveToPoint:CGPointMake(topLeft.x, topLeft.y + self.cornerRadius)];
    [path addQuadCurveToPoint:CGPointMake(topLeft.x + self.cornerRadius, topLeft.y)
                 controlPoint:topLeft];
    
    // Top edge arrow
    if (self.currentArrowDirection == MITCalloutArrowDirectionTop) {
        CGFloat arrowLeftX = topLeft.x + controlPoint.x - halfArrowWidth;
        CGFloat arrowMidX = topLeft.x + controlPoint.x;
        CGFloat arrowRightX = topLeft.x + controlPoint.x + halfArrowWidth;
        
        CGPoint bottomLeftPointOfArrowTipCurve = CGPointMake(arrowMidX - arrowTipWidth, topLeft.y - arrowHeight + arrowTipHeight);
        CGPoint bottomRightPointOfArrowTipCurve = CGPointMake(arrowMidX + arrowTipWidth, topLeft.y - arrowHeight + arrowTipHeight);
        
        [path addLineToPoint:CGPointMake(arrowLeftX, topLeft.y)];
        [path addQuadCurveToPoint:bottomLeftPointOfArrowTipCurve controlPoint:CGPointMake(arrowLeftX + arrowBaseBezierControlInset, topLeft.y)];
        [path addQuadCurveToPoint:bottomRightPointOfArrowTipCurve controlPoint:CGPointMake(arrowMidX, bottomLeftPointOfArrowTipCurve.y - (2 * arrowTipHeight))];
        [path addQuadCurveToPoint:CGPointMake(arrowRightX, topLeft.y) controlPoint:CGPointMake(arrowRightX - arrowBaseBezierControlInset, topLeft.y)];
    }
    
    // Top edge finisher
    [path addLineToPoint:CGPointMake(topRight.x - self.cornerRadius, topRight.y)];
    
    // Top right corner
    [path addQuadCurveToPoint:CGPointMake(topRight.x, topRight.y + self.cornerRadius)
                 controlPoint:topRight];
    
    // Right edge arrow
    if (self.currentArrowDirection == MITCalloutArrowDirectionRight) {
        CGFloat arrowTopY = topRight.y + controlPoint.y - halfArrowWidth;
        CGFloat arrowMidY = topRight.y + controlPoint.y;
        CGFloat arrowBottomY = topRight.y + controlPoint.y + halfArrowWidth;
        
        CGPoint topLeftPointOfArrowTipCurve = CGPointMake(topRight.x + arrowHeight - arrowTipHeight, arrowMidY - arrowTipWidth);
        CGPoint bottomLeftPointOfArrowTipCurve = CGPointMake(topRight.x + arrowHeight - arrowTipHeight, arrowMidY + arrowTipWidth);
        
        [path addLineToPoint:CGPointMake(topRight.x, arrowTopY)];
        [path addQuadCurveToPoint:topLeftPointOfArrowTipCurve controlPoint:CGPointMake(topRight.x, arrowTopY + arrowBaseBezierControlInset)];
        [path addQuadCurveToPoint:bottomLeftPointOfArrowTipCurve controlPoint:CGPointMake(topLeftPointOfArrowTipCurve.x + (2 * arrowTipHeight), arrowMidY)];
        [path addQuadCurveToPoint:CGPointMake(topRight.x, arrowBottomY) controlPoint:CGPointMake(topRight.x, arrowBottomY - arrowBaseBezierControlInset)];
    }
    
    // Right edge finisher
    [path addLineToPoint:CGPointMake(lowerRight.x, lowerRight.y - self.cornerRadius)];
    
    // Bottom right corner
    [path addQuadCurveToPoint:CGPointMake(lowerRight.x - self.cornerRadius, lowerRight.y)
                 controlPoint:lowerRight];
    
    // Bottom edge arrow
    if (self.currentArrowDirection == MITCalloutArrowDirectionBottom) {
        CGFloat arrowRightX = lowerLeft.x + controlPoint.x + halfArrowWidth;
        CGFloat arrowMidX = lowerLeft.x + controlPoint.x;
        CGFloat arrowLeftX = lowerLeft.x + controlPoint.x - halfArrowWidth;
        
        CGPoint topRightPointOfArrowTipCurve = CGPointMake(arrowMidX + arrowTipWidth, lowerRight.y + arrowHeight - arrowTipHeight);
        CGPoint topLeftPointOfArrowTipCurve = CGPointMake(arrowMidX - arrowTipWidth, lowerRight.y + arrowHeight - arrowTipHeight);
        
        [path addLineToPoint:CGPointMake(arrowRightX, lowerRight.y)];
        [path addQuadCurveToPoint:topRightPointOfArrowTipCurve controlPoint:CGPointMake(arrowRightX - arrowBaseBezierControlInset, lowerRight.y)];
        [path addQuadCurveToPoint:topLeftPointOfArrowTipCurve controlPoint:CGPointMake(arrowMidX, topRightPointOfArrowTipCurve.y + (2 * arrowTipHeight))];
        [path addQuadCurveToPoint:CGPointMake(arrowLeftX, lowerRight.y) controlPoint:CGPointMake(arrowLeftX + arrowBaseBezierControlInset, lowerRight.y)];
    }
    
    // Bottom edge finisher
    [path addLineToPoint:CGPointMake(lowerLeft.x + self.cornerRadius, lowerLeft.y)];
    
    // Bottom left corner
    [path addQuadCurveToPoint:CGPointMake(lowerLeft.x, lowerLeft.y - self.cornerRadius)
                 controlPoint:lowerLeft];
    
    // Left edge arrow
    if (self.currentArrowDirection == MITCalloutArrowDirectionLeft) {
        CGFloat arrowBottomY = topLeft.y + controlPoint.y + halfArrowWidth;
        CGFloat arrowMidY = topLeft.y + controlPoint.y;
        CGFloat arrowTopY = topLeft.y + controlPoint.y - halfArrowWidth;
        
        CGPoint bottomRightPointOfArrowTipCurve = CGPointMake(lowerLeft.x - arrowHeight + arrowTipHeight, arrowMidY + arrowTipWidth);
        CGPoint topRightPointOfArrowTipCurve = CGPointMake(lowerLeft.x - arrowHeight + arrowTipHeight, arrowMidY - arrowTipWidth);
        
        [path addLineToPoint:CGPointMake(lowerLeft.x, arrowBottomY)];
        [path addQuadCurveToPoint:bottomRightPointOfArrowTipCurve controlPoint:CGPointMake(lowerLeft.x, arrowBottomY - arrowBaseBezierControlInset)];
        [path addQuadCurveToPoint:topRightPointOfArrowTipCurve controlPoint:CGPointMake(bottomRightPointOfArrowTipCurve.x - (2 * arrowTipHeight), arrowMidY)];
        [path addQuadCurveToPoint:CGPointMake(lowerLeft.x, arrowTopY) controlPoint:CGPointMake(lowerLeft.x, arrowTopY + arrowBaseBezierControlInset)];
    }
    
    // Left edge finisher
    [path closePath];
    
    self.maskingPath = path;
    
    [self updateLayersForNewPath:path animated:animated];
}

- (void)updateLayersForNewPath:(UIBezierPath *)path animated:(BOOL)animated {
    
    // Possibly better ways to implement this animation and sync w/ bounds change.  Currently full animation support is not implemented.
    if (animated) {
        CABasicAnimation *pathAnim = [CABasicAnimation animationWithKeyPath:@"path"];
        pathAnim.toValue = (id)path.CGPath;
        
        CAAnimationGroup *animGroup = [CAAnimationGroup animation];
        animGroup.animations = @[pathAnim];
        animGroup.removedOnCompletion = NO;
        animGroup.duration = 0.25;
        animGroup.fillMode = kCAFillModeBoth;
        
        [self.maskingShapeLayer addAnimation:animGroup forKey:nil];
        [self.shadowShapeLayer addAnimation:animGroup forKey:nil];
    } else {
        for (CAShapeLayer *layer in @[self.maskingShapeLayer, self.shadowShapeLayer]) {
            layer.path = path.CGPath;
            [layer didChangeValueForKey:@"path"];
        }
    }
}

#pragma mark - Setters

- (void)setTitleText:(NSString *)titleText {
    if (self.hasDefaultContentView) {
        MITCalloutViewDefaultContentView *contentView = (MITCalloutViewDefaultContentView *)self.contentView;
        contentView.titleLabel.text = titleText;
        [self reorientPresentation];
    }
    _titleText = titleText;
}

- (void)setSubtitleText:(NSString *)subtitleText {
    if (self.hasDefaultContentView) {
        MITCalloutViewDefaultContentView *contentView = (MITCalloutViewDefaultContentView *)self.contentView;
        contentView.subtitleLabel.text = subtitleText;
        [self reorientPresentation];
    }
    _subtitleText = subtitleText;
}

- (UIView *)contentView {
    if (!_contentView) {
        MITCalloutViewDefaultContentView *contentView = [MITCalloutViewDefaultContentView new];
        contentView.titleLabel.text = self.titleText;
        contentView.subtitleLabel.text = self.subtitleText;
        [self setContentView:contentView];
    }
    return _contentView;
}

- (void)setContentView:(UIView *)contentView {
    [_contentView removeFromSuperview];
    _contentView = contentView;
    
    if (contentView) {
        [self addSubview:contentView];
        
        // Store size at time of setting if not already set -- Can also be set explicitly
        self.contentViewPreferredSize = contentView.bounds.size;
        
        CGRect bounds = self.bounds;
        bounds.size.height = CGRectGetHeight(contentView.bounds) + self.internalInsets.top + self.internalInsets.bottom;
        bounds.size.width = CGRectGetWidth(contentView.bounds) + self.internalInsets.left + self.internalInsets.right;
        
        switch (self.currentArrowDirection) {
            case MITCalloutArrowDirectionTop:
            case MITCalloutArrowDirectionBottom:
                bounds.size.height += self.arrowSize.height;
                break;
            case MITCalloutArrowDirectionLeft:
            case MITCalloutArrowDirectionRight:
                bounds.size.width += self.arrowSize.height;
                break;
            case MITCalloutArrowDirectionNone:
                break;
        }
        
        self.bounds = bounds;
        
        NSLayoutConstraint *top, *left, *right, *bottom;
        top = [NSLayoutConstraint constraintWithItem:contentView
                                           attribute:NSLayoutAttributeTop
                                           relatedBy:NSLayoutRelationEqual
                                              toItem:self
                                           attribute:NSLayoutAttributeTop
                                          multiplier:1.0
                                            constant:self.internalInsets.top];
        
        left = [NSLayoutConstraint constraintWithItem:contentView
                                            attribute:NSLayoutAttributeLeft
                                            relatedBy:NSLayoutRelationEqual
                                               toItem:self
                                            attribute:NSLayoutAttributeLeft
                                           multiplier:1.0
                                             constant:self.internalInsets.left];
        
        right = [NSLayoutConstraint constraintWithItem:contentView
                                             attribute:NSLayoutAttributeRight
                                             relatedBy:NSLayoutRelationEqual
                                                toItem:self
                                             attribute:NSLayoutAttributeRight
                                            multiplier:1.0
                                              constant:-self.internalInsets.right];
        
        bottom = [NSLayoutConstraint constraintWithItem:contentView
                                              attribute:NSLayoutAttributeBottom
                                              relatedBy:NSLayoutRelationEqual
                                                 toItem:self
                                              attribute:NSLayoutAttributeBottom
                                             multiplier:1.0
                                               constant:-self.internalInsets.bottom];
        
        contentView.translatesAutoresizingMaskIntoConstraints = false;
        [self removeConstraints:self.constraints];
        [self addConstraints:@[top, left, right, bottom]];
        
        self.topContentConstraint = top;
        self.leftContentConstraint = left;
        self.bottomContentConstraint = bottom;
        self.rightContentConstraint = right;
        
        [self reorientPresentation];
    }
}

#pragma mark - Arrow

- (void)setCurrentArrowDirection:(MITCalloutArrowDirection)currentArrowDirection {
    _currentArrowDirection = currentArrowDirection;
    [self resizeAndPositionSubviews];
}

#pragma mark - Presentation

- (void)updatePresentation {
    [self presentFromRect:self.presentationRect inView:self.presentationView withConstrainingView:self.constrainingView];
}

- (void)presentFromRect:(CGRect)rect inView:(UIView *)view {
    [self presentFromRect:rect inView:view withConstrainingView:view];
}

- (void)presentFromRect:(CGRect)presentationRect inView:(UIView *)view withConstrainingView:(UIView *)constrainingView {
    [self presentFromRect:presentationRect inView:view withConstrainingView:constrainingView animated:YES];
}

- (void)presentFromRect:(CGRect)presentationRect inView:(UIView *)view withConstrainingView:(UIView *)constrainingView animated:(BOOL)animated {
    
    self.presentationRect = presentationRect;
    self.presentationView = view;
    self.constrainingView = constrainingView;
    
    presentationRect = [view convertRect:presentationRect toView:constrainingView];
    
    CGFloat availableTopSpace = CGRectGetMinY(presentationRect);
    CGFloat availableRightSpace = CGRectGetWidth(constrainingView.bounds) - CGRectGetMaxX(presentationRect);
    CGFloat availableBottomSpace = CGRectGetHeight(constrainingView.bounds) - CGRectGetMaxY(presentationRect);
    CGFloat availableLeftSpace = CGRectGetMinX(presentationRect);
    
    CGFloat constraintHeight = CGRectGetHeight(constrainingView.bounds);
    CGFloat constraintWidth = CGRectGetWidth(constrainingView.bounds);
    
    self.contentViewMaxSize = CGSizeMake(constraintWidth - self.contentViewConstraintPaddingHorizontal, constraintHeight - self.contentViewConstraintPaddingVertical);
    
    // Reset to none to readjust our views for none and measure
    self.currentArrowDirection = MITCalloutArrowDirectionNone;
    CGFloat necessaryWidth = CGRectGetWidth(self.bounds) + self.externalInsets.left + self.externalInsets.right + self.arrowSize.height + self.arrowOffset;
    CGFloat necessaryHeight = CGRectGetHeight(self.bounds) + self.externalInsets.top + self.externalInsets.bottom + self.arrowSize.height + self.arrowOffset;
    
    // If arrow is top or bottom, this is the maximum x control point allowed for proper drawing
    CGFloat maximumTopBottomX = CGRectGetWidth(constrainingView.bounds) - self.minControlPointX - self.externalInsets.right;
    CGFloat minimumTopBottomX = [self minControlPointX] + self.externalInsets.left;
    CGFloat midRectX = CGRectGetMidX(presentationRect);
    
    // If arrow is left or right, what's the maximum y position that would be allowed
    CGFloat maximumLeftRightY = CGRectGetHeight(constrainingView.bounds) - self.minControlPointY - self.externalInsets.bottom;
    CGFloat minimumLeftRightY = [self minControlPointY] + self.externalInsets.top;
    CGFloat midRectY = CGRectGetMidY(presentationRect);
    
    CGRect targetFrame = CGRectZero;
    CGFloat originX = 0, originY = 0;
    
    if ([self isArrowDirectionPermitted:MITCalloutArrowDirectionBottom] && necessaryHeight < availableTopSpace && minimumTopBottomX <= midRectX && midRectX <= maximumTopBottomX) {
        self.currentArrowDirection = MITCalloutArrowDirectionBottom;
        originX = CGRectGetMidX(presentationRect) - (CGRectGetWidth(self.bounds) / 2.0);
        originY = CGRectGetMinY(presentationRect) - self.arrowOffset - CGRectGetHeight(self.bounds);
    } else if ([self isArrowDirectionPermitted:MITCalloutArrowDirectionTop] && necessaryHeight < availableBottomSpace && minimumTopBottomX <= midRectX && midRectX <= maximumTopBottomX) {
        self.currentArrowDirection = MITCalloutArrowDirectionTop;
        originX = CGRectGetMidX(presentationRect) - (CGRectGetWidth(self.bounds) / 2.0);
        originY = CGRectGetMaxY(presentationRect) + self.arrowOffset;
    } else if ([self isArrowDirectionPermitted:MITCalloutArrowDirectionLeft] && necessaryWidth < availableRightSpace && minimumLeftRightY <= midRectY && midRectY <= maximumLeftRightY) {
        self.currentArrowDirection = MITCalloutArrowDirectionLeft;
        originX = CGRectGetMaxX(presentationRect) + self.arrowOffset;
        originY = CGRectGetMidY(presentationRect) - (CGRectGetHeight(self.bounds) / 2.0);
    } else if ([self isArrowDirectionPermitted:MITCalloutArrowDirectionRight] && necessaryWidth < availableLeftSpace && minimumLeftRightY <= midRectY && midRectY <= maximumLeftRightY) {
        self.currentArrowDirection = MITCalloutArrowDirectionRight;
        originX = CGRectGetMinX(presentationRect) - self.arrowOffset - CGRectGetWidth(self.bounds);
        originY = CGRectGetMidY(presentationRect) - (CGRectGetHeight(self.bounds) / 2.0);
    }
    
    switch (self.currentArrowDirection) {
        case MITCalloutArrowDirectionTop:
        case MITCalloutArrowDirectionBottom:
            if (originX < self.externalInsets.left) {
                originX = self.externalInsets.left;
            } else if (constraintWidth - (originX + CGRectGetWidth(self.bounds)) < self.externalInsets.right) {
                originX = constraintWidth - self.externalInsets.right - CGRectGetWidth(self.bounds);
            }
            break;
        case MITCalloutArrowDirectionLeft:
        case MITCalloutArrowDirectionRight:
            if (originY < self.externalInsets.top) {
                originY = self.externalInsets.top;
            } else if (constraintHeight - (originY + CGRectGetHeight(self.bounds)) < self.externalInsets.bottom) {
                originY = constraintHeight - self.externalInsets.bottom - CGRectGetHeight(self.bounds);
            }
            break;
        case MITCalloutArrowDirectionNone:
            break;
    }
    
    /*
     Unable to fit in bounds -- Find best possible offscreen placement
     */
    CGFloat presentationRectMiddleX = CGRectGetMidX(presentationRect);
    CGFloat constraintHalfWidth = constraintWidth / 2.0;
    CGFloat presentationRectMiddleY = CGRectGetMidY(presentationRect);
    CGFloat constraintHalfHeight = constraintHeight / 2.0;
    
    NSSortDescriptor *highestToLowest = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:NO];
    NSArray *availableSpace = [@[@(availableTopSpace), @(availableBottomSpace), @(availableLeftSpace), @(availableRightSpace)] sortedArrayUsingDescriptors:@[highestToLowest]];
    if (self.currentArrowDirection == MITCalloutArrowDirectionNone && self.permittedArrowDirections != MITCalloutArrowDirectionNone) {
        for (NSNumber *space in availableSpace) {
            CGFloat availableSpace = space.floatValue;
            if (availableSpace == availableTopSpace && [self isArrowDirectionPermitted:MITCalloutArrowDirectionBottom]) {
                self.currentArrowDirection = MITCalloutArrowDirectionBottom;
                if (presentationRectMiddleX <= constraintHalfWidth) {
                    originX = presentationRectMiddleX - [self minControlPointX];
                } else {
                    originX = presentationRectMiddleX - [self maxControlPointX];
                }
                originY = CGRectGetMinY(presentationRect) - self.arrowOffset - CGRectGetHeight(self.bounds);
                break;
            } else if (availableSpace == availableBottomSpace && [self isArrowDirectionPermitted:MITCalloutArrowDirectionTop]) {
                self.currentArrowDirection = MITCalloutArrowDirectionTop;
                if (presentationRectMiddleX <= constraintHalfWidth) {
                    originX = presentationRectMiddleX - [self minControlPointX];
                } else {
                    originX = presentationRectMiddleX - [self maxControlPointX];
                }
                originY = CGRectGetMaxY(presentationRect) + self.arrowOffset;
                break;
            } else if (availableSpace == availableRightSpace && [self isArrowDirectionPermitted:MITCalloutArrowDirectionLeft]) {
                self.currentArrowDirection = MITCalloutArrowDirectionLeft;
                originX = CGRectGetMaxX(presentationRect) + self.arrowOffset;
                if (presentationRectMiddleY <= constraintHalfHeight) {
                    originY = presentationRectMiddleY - [self minControlPointY];
                } else {
                    originY = presentationRectMiddleY - [self maxControlPointY];
                }
                break;
            } else if (availableSpace == availableLeftSpace && [self isArrowDirectionPermitted:MITCalloutArrowDirectionRight]) {
                self.currentArrowDirection = MITCalloutArrowDirectionRight;
                originX = CGRectGetMinX(presentationRect) - self.arrowOffset - CGRectGetWidth(self.bounds);
                if (presentationRectMiddleY <= constraintHalfHeight) {
                    originY = presentationRectMiddleY - [self minControlPointY];
                } else {
                    originY = presentationRectMiddleY - [self maxControlPointY];
                }
                break;
            }
        }
    } else if (self.permittedArrowDirections == MITCalloutArrowDirectionNone) {
        originX = presentationRectMiddleX - CGRectGetMidX(self.bounds);
        originY = presentationRectMiddleY - CGRectGetMidY(self.bounds);
    }
    
    CGRect frame = self.frame;
    frame.origin.x = originX;
    frame.origin.y = originY;
    targetFrame = frame;
    
    CGFloat controlX = CGRectGetMidX(presentationRect) - CGRectGetMinX(targetFrame);
    CGFloat controlY = CGRectGetMidY(presentationRect) - CGRectGetMinY(targetFrame);
    switch (self.currentArrowDirection) {
        case MITCalloutArrowDirectionTop:
            self.controlPoint = CGPointMake(controlX, 0);
            break;
        case MITCalloutArrowDirectionLeft:
            self.controlPoint = CGPointMake(0, controlY);
            break;
        case MITCalloutArrowDirectionBottom:
            self.controlPoint = CGPointMake(controlX, CGRectGetHeight(targetFrame));
            break;
        case MITCalloutArrowDirectionRight:
            self.controlPoint = CGPointMake(CGRectGetWidth(targetFrame), controlY);
            break;
        case MITCalloutArrowDirectionNone:
            self.controlPoint = CGPointZero;
            break;
    }
    
    // Must do these calculations before converting rect back. and after targetFrame has been set.
    CGPoint offscreenOffset = CGPointZero;
    if (targetFrame.origin.x < self.externalInsets.left) {
        offscreenOffset.x = targetFrame.origin.x - self.externalInsets.left;
    } else if (CGRectGetMaxX(targetFrame) > CGRectGetWidth(constrainingView.bounds) - self.externalInsets.right) {
        offscreenOffset.x = CGRectGetMaxX(targetFrame) - (CGRectGetWidth(constrainingView.bounds) - self.externalInsets.right);
    }
    
    if (targetFrame.origin.y < self.externalInsets.top) {
        offscreenOffset.y = targetFrame.origin.y - self.externalInsets.top;
    } else if (CGRectGetMaxY(targetFrame) > CGRectGetHeight(constrainingView.bounds) - self.externalInsets.bottom) {
        offscreenOffset.y = CGRectGetMaxY(targetFrame) - (CGRectGetHeight(constrainingView.bounds) - self.externalInsets.bottom);
    }
    
    
    // We've been positioning the view in the constraining view, now lets translate it back to the presentation view
    targetFrame = [constrainingView convertRect:targetFrame toView:view];
    self.frame = targetFrame;
    
    __weak __typeof(self) weakSelf = self;
    [self addToView:view animated:animated withCompletion:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!CGPointEqualToPoint(offscreenOffset, CGPointZero)) {
            [strongSelf.delegate calloutView:strongSelf positionedOffscreenWithOffset:offscreenOffset];
        }
    }];
    
}

- (void)addToView:(UIView *)view animated:(BOOL)animated withCompletion:(void(^)(void))completion {
    if (![view.subviews containsObject:self]) {
        if (animated) {
            self.alpha = 0.4;
            self.transform = CGAffineTransformMakeScale(0.82, 0.82);
            [view addSubview:self];
            [UIView animateWithDuration:0.25
                                  delay:0.0
                 usingSpringWithDamping:0.5
                  initialSpringVelocity:1.0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                 self.alpha = 1;
                                 self.transform = CGAffineTransformMakeScale(1.0, 1.0);
                             } completion:^(BOOL finished) {
                                 if (completion) {
                                     completion();
                                 }
                             }];
        } else {
            self.alpha = 1.0;
            self.transform = CGAffineTransformMakeScale(1.0, 1.0);
            [view addSubview:self];
            if (completion) {
                completion();
            }
        }
    } else if (completion) {
        completion();
    }
}

- (void)dismissCallout {
    [self removeFromSuperview];
    if ([self.delegate respondsToSelector:@selector(calloutViewRemovedFromViewHierarchy:)]) {
        [self.delegate calloutViewRemovedFromViewHierarchy:self];
    }
}

#pragma mark - Calculation Helpers

- (CGFloat)minControlPointX {
    return self.cornerRadius + (self.arrowSize.width / 2.0);
}
- (CGFloat)minControlPointY {
    return self.cornerRadius + (self.arrowSize.width / 2.0);
}
- (CGFloat)maxControlPointX {
    return CGRectGetWidth(self.bounds) - [self minControlPointX];
}
- (CGFloat)maxControlPointY {
    return CGRectGetHeight(self.bounds) - [self minControlPointY];
}
- (CGFloat)minimumEdgeLength {
    return self.arrowSize.width + (self.cornerRadius * 2.0);
}

- (CGRect)framingRect {
    
    CGFloat arrowHeight = self.arrowSize.height;
    
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat adjustedOriginY = 0;
    CGFloat adjustedOriginX = 0;
    CGFloat adjustedWidth = width;
    CGFloat adjustedHeight = height;
    
    switch (self.currentArrowDirection) {
        case MITCalloutArrowDirectionTop:
            adjustedOriginY = arrowHeight;
            adjustedHeight = height - arrowHeight;
            break;
        case MITCalloutArrowDirectionLeft:
            adjustedOriginX = arrowHeight;
            adjustedWidth = width - arrowHeight;
            break;
        case MITCalloutArrowDirectionBottom:
            adjustedHeight = height - arrowHeight;
            break;
        case MITCalloutArrowDirectionRight:
            adjustedWidth = width - arrowHeight;
            break;
        case MITCalloutArrowDirectionNone:
            break;
    }
    
    return CGRectMake(adjustedOriginX, adjustedOriginY, adjustedWidth, adjustedHeight);
}

- (BOOL)isArrowDirectionPermitted:(MITCalloutArrowDirection)direction {
    return ((direction & self.permittedArrowDirections) == direction);
}

#pragma mark -

- (BOOL)hasDefaultContentView {
    return [self.contentView isKindOfClass:[MITCalloutViewDefaultContentView class]];
}

#pragma mark - Layers Setup

- (CAShapeLayer *)shadowShapeLayer {
    if (!_shadowShapeLayer) {
        _shadowShapeLayer = [CAShapeLayer new];
        _shadowShapeLayer.lineWidth = 1.0;
        _shadowShapeLayer.fillColor = [UIColor clearColor].CGColor;
        _shadowShapeLayer.strokeColor = [UIColor colorWithWhite:0.74 alpha:0.78].CGColor;
        // Must have default path set for animations to work
        _shadowShapeLayer.path = [UIBezierPath bezierPath].CGPath;
        [self.layer addSublayer:_shadowShapeLayer];
    }
    return _shadowShapeLayer;
}

- (CAShapeLayer *)maskingShapeLayer {
    if (!_maskingShapeLayer) {
        _maskingShapeLayer = [CAShapeLayer new];
        // Must have default path set for animations to work
        _maskingShapeLayer.path = [UIBezierPath bezierPath].CGPath;
        self.layer.mask = _maskingShapeLayer;
    }
    return _maskingShapeLayer;
}

#pragma mark - Touch Handling

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self highlight];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self unhighlight];
    [self handleTouchesFinishedWithTouch:touches.anyObject];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self unhighlight];
    [self handleTouchesFinishedWithTouch:touches.anyObject];
}

// In some cases cancelled is called on a legitimate touch.  This is likely related to the hit overrides necessary to present a view outside of its bounds and receive touches.  This is a workaround.
- (void)handleTouchesFinishedWithTouch:(UITouch *)touch {
    CGPoint location = [touch locationInView:self];
    if ([self.maskingPath containsPoint:location]) {
        [self.delegate calloutViewTapped:self];
    }
}

#pragma mark - Highlight

- (void)highlight {
    if (self.shouldHighlightOnTouch) {
        for (UIView *v in self.subviews) {
            v.alpha = 0.6;
        }
        self.backgroundColor = [UIColor colorWithWhite:0.90 alpha:1.0];
    }
}

- (void)unhighlight {
    if (self.shouldHighlightOnTouch) {
        for (UIView *v in self.subviews) {
            v.alpha = 1.0;
        }
        self.backgroundColor = [UIColor whiteColor];
    }
}

#pragma mark - Hit Test

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return [self.maskingPath containsPoint:point];
}

@end
