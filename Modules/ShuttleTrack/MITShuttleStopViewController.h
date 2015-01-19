#import <UIKit/UIKit.h>

@class MITShuttleStop;
@class MITShuttleRoute;

typedef NS_ENUM(NSUInteger, MITShuttleStopViewOption) {
    MITShuttleStopViewOptionAll,
    MITShuttleStopViewOptionIntersectingOnly
};


@protocol MITShuttleStopViewControllerDelegate;

@interface MITShuttleStopViewController : UITableViewController

@property (strong, nonatomic) MITShuttleStop *stop;
@property (strong, nonatomic) MITShuttleRoute *route;

@property (nonatomic, weak) id<MITShuttleStopViewControllerDelegate> delegate;

@property (nonatomic) MITShuttleStopViewOption viewOption;
@property (nonatomic) BOOL shouldHideFooter;
@property (nonatomic, strong) NSString *tableTitle;

- (instancetype)initWithStyle:(UITableViewStyle)style stop:(MITShuttleStop *)stop route:(MITShuttleRoute *)route;

- (CGFloat)preferredContentHeight;
- (void)setFixedContentSize:(CGSize)size;

@end

@protocol MITShuttleStopViewControllerDelegate <NSObject>

@optional
- (void)shuttleStopViewController:(MITShuttleStopViewController *)shuttleStopViewController didSelectRoute:(MITShuttleRoute *)route withStop:(MITShuttleStop *)stop;

@end
