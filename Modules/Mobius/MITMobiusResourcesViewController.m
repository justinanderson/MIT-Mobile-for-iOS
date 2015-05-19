#import <MapKit/MapKit.h>

#import "MITMobiusResourcesViewController.h"
#import "MITMobiusResource.h"
#import "MITMobiusResourceHours.h"
#import "Foundation+MITAdditions.h"
#import "CoreData+MITAdditions.h"
#import "MITMobiusRoomSet.h"
#import "UITableView+DynamicSizing.h"
#import "MITMobiusResourcesTableSection.h"

// UITableView Headers/Cells
#import "MITMobiusShopHeader.h"
#import "MITMobiusResourceTableViewCell.h"
#import "MITMobiusResourceView.h"
#import "MITActivityTableViewCell.h"

// Map-related classes
#import "MITMapPlaceAnnotationView.h"
#import "MITMobiusCalloutContentView.h"
#import "MITTiledMapView.h"
#import "MITCalloutView.h"

#pragma mark - Static
NSString* const MITMobiusResourceShopHeaderReuseIdentifier = @"MITMobiusResourceShopHeader";
NSString* const MITMobiusResourceCellReuseIdentifier = @"MITMobiusResourceCell";
NSString* const MITMobiusResourceLoadingCellReuseIdentifier = @"MITMobiusResourceLoadingCell";
NSString* const MITMobiusResourceNoResultsCellReuseIdentifier = @"MITMobiusResourceNoResultsCell";
NSString* const MITMobiusResourceRoomAnnotationReuseIdentifier = @"MITMobiusResourceRoomAnnotation";

#pragma mark - Main Implementation
@interface MITMobiusResourcesViewController () <UITableViewDelegate, UITableViewDataSourceDynamicSizing, MKMapViewDelegate, MITCalloutViewDelegate>
@property (nonatomic,copy) NSArray *sections;
@property (nonatomic,weak) MITLoadingActivityView *activityView;
@property (nonatomic,weak) MITCalloutView *calloutView;
@end

@implementation MITMobiusResourcesViewController {
    NSLayoutConstraint *_mapViewAspectHeightConstraint;
    NSLayoutConstraint *_mapViewFullScreenHeightConstraint;
    NSMapTable *_sectionNumberByButton;
    CGFloat _mapVerticalOffset;
}

@synthesize mapView = _mapView;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _showsMap = YES;
    }

    return self;
}

- (void)loadView
{
    UIView *view = [[UIView alloc] init];
    self.view = view;

    // Setup the table view
    UITableView *tableView = [[UITableView alloc] init];
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    tableView.dataSource = self;
    tableView.delegate = self;
    [view addSubview:tableView];
    self.tableView = tableView;

    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tableView]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:@{@"tableView" : tableView}]];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tableView]|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:@{@"tableView" : tableView}]];

    // Setup the map view
    MITTiledMapView *mapView = [[MITTiledMapView alloc] init];
    mapView.translatesAutoresizingMaskIntoConstraints = NO;
    mapView.userInteractionEnabled = NO;
    [mapView setMapDelegate:self];
    [view addSubview:mapView];
    self.mapView = mapView;

    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[mapView]-(>=0)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:@{@"mapView" : mapView}]];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(0)-[mapView]-(0)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:@{@"mapView" : mapView}]];
    NSLayoutConstraint *mapHeightConstraint = [NSLayoutConstraint constraintWithItem:mapView
                                                                           attribute:NSLayoutAttributeHeight
                                                                           relatedBy:NSLayoutRelationEqual
                                                                              toItem:mapView
                                                                           attribute:NSLayoutAttributeWidth
                                                                          multiplier:0.66
                                                                            constant:0];
    mapHeightConstraint.priority = UILayoutPriorityDefaultHigh;
    [mapView addConstraint:mapHeightConstraint];
    _mapViewAspectHeightConstraint = mapHeightConstraint;

    NSLayoutConstraint *mapFixedHeightConstraint = [NSLayoutConstraint constraintWithItem:mapView
                                                                                attribute:NSLayoutAttributeHeight
                                                                                relatedBy:NSLayoutRelationEqual
                                                                                   toItem:nil
                                                                                attribute:NSLayoutAttributeNotAnAttribute
                                                                               multiplier:1.
                                                                                 constant:0.];
    mapFixedHeightConstraint.priority = UILayoutPriorityDefaultLow;
    [mapView addConstraint:mapFixedHeightConstraint];
    _mapViewFullScreenHeightConstraint = mapFixedHeightConstraint;

    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleShowMapFullScreenGesture:)];
    self.mapFullScreenGesture = gestureRecognizer;
    [view addGestureRecognizer:gestureRecognizer];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _sectionNumberByButton = [NSMapTable weakToWeakObjectsMapTable];

    UINib *resourceTableViewCellNib = [UINib nibWithNibName:@"MITMobiusResourceTableViewCell" bundle:nil];
    [self.tableView registerNib:resourceTableViewCellNib forDynamicCellReuseIdentifier:MITMobiusResourceCellReuseIdentifier];
    [self.tableView registerClass:[MITActivityTableViewCell class] forCellReuseIdentifier:MITMobiusResourceLoadingCellReuseIdentifier];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:MITMobiusResourceNoResultsCellReuseIdentifier];
    [self.tableView registerNib:[MITMobiusShopHeader searchHeaderNib] forHeaderFooterViewReuseIdentifier:MITMobiusResourceShopHeaderReuseIdentifier];
}

- (void)viewWillAppear:(BOOL)animated
{
    NSAssert(self.managedObjectContext,@"a valid managed object context was not configured");
    [super viewWillAppear:animated];
    [self reloadData];
}

- (void)updateViewConstraints
{
    _mapViewAspectHeightConstraint.constant = _mapVerticalOffset;
    [super updateViewConstraints];
}

- (void)updateMapWithContentOffset:(CGPoint)contentOffset
{
    CGFloat yOffset = contentOffset.y;
    if (yOffset <= 0) {
        self.mapView.layer.transform = CATransform3DIdentity;
        _mapVerticalOffset = -yOffset;
    } else {
        self.mapView.layer.transform = CATransform3DMakeTranslation(0, -yOffset, 0);
        _mapVerticalOffset = 0.;
    }

    [self.view setNeedsUpdateConstraints];
    [self.view setNeedsLayout];
}

#pragma mark Property accessors/setters
- (BOOL)mapViewIsLoaded
{
    return (_mapView != nil);
}

- (MITTiledMapView*)mapView
{
    if (self.showsMap == NO) {
        return nil;
    } else if ([self mapViewIsLoaded] == NO) {
        CGRect mapFrame = CGRectZero;
        mapFrame.size.width = CGRectGetWidth(self.tableView.bounds);
        MITTiledMapView *mapView = [[MITTiledMapView alloc] initWithFrame:mapFrame];
        [self.view addSubview:mapView];

        _mapView = mapView;
    }

    return _mapView;
}

- (void)setResources:(NSArray *)resources
{
    if (![_resources isEqualToArray:resources]) {
        self.sections = nil;

        if (resources == nil) {
            _resources = nil;
        } else {
            NSAssert(self.managedObjectContext,@"a valid managed object context was not configured");
            [self.managedObjectContext performBlockAndWait:^{
                _resources = [self.managedObjectContext transferManagedObjects:resources];
            }];
        }
    }

    if ([self isViewLoaded]) {
        [self reloadData];
    }
}

- (void)setSelectedResource:(MITMobiusResource *)selectedResource
{
    if (selectedResource) {
        self.selectedResources = @[selectedResource];
    } else {
        self.selectedResources = nil;
    }
}

- (MITMobiusResource*)selectedResource
{
    return [self.selectedResources firstObject];
}

- (NSArray*)sections
{
    if (_resources == nil) {
        return nil;
    } else if (_sections == nil) {
        __block NSMutableArray *sections = [[NSMutableArray alloc] init];

        [self.managedObjectContext performBlockAndWait:^{
            NSMutableDictionary *sectionsByName = [[NSMutableDictionary alloc] init];
            [_resources enumerateObjectsUsingBlock:^(MITMobiusResource *resource, NSUInteger idx, BOOL *stop) {
                NSString *key = nil;
                if (resource.roomset.name) {
                    key = [NSString stringWithFormat:@"%@ (%@)",resource.roomset.name, resource.room];
                } else {
                    key = [resource.room copy];
                }

                MITMobiusResourcesTableSection *section = sectionsByName[key];
                if (section == nil) {
                    section = [[MITMobiusResourcesTableSection alloc] initWithName:key];
                    sectionsByName[key] = section;
                }

                [section addResource:resource];
            }];

            NSArray *sortedSectionNames = [[sectionsByName allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *key1, NSString *key2) {
                return [key1 compare:key2 options:(NSNumericSearch | NSCaseInsensitiveSearch | NSForcedOrderingSearch)];
            }];

            [sortedSectionNames enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
                [sections addObject:sectionsByName[key]];
            }];
        }];

        _sections = sections;
    }

    return _sections;
}

#pragma mark Data Helper Methods
- (void)reloadData
{
    [self.tableView reloadData];

    MKMapView *mapView = self.mapView.mapView;
    mapView.showsUserLocation = NO;
    mapView.userTrackingMode = MKUserTrackingModeNone;
    [mapView removeAnnotations:mapView.annotations];
    [mapView addAnnotations:self.sections];

    [self recenterMapView];
}

- (void)recenterMapView
{
    MKMapView *mapView = self.mapView.mapView;
    if (self.isLoading || (self.sections.count == 0)) {
        [mapView setRegion:kMITShuttleDefaultMapRegion animated:YES];
    } else if (self.sections.count > 0) {
        [mapView showAnnotations:self.sections animated:YES];
    }
}

- (void)setShowsMap:(BOOL)showsMap
{
    [self setShowsMap:showsMap animated:NO];
}

- (void)setShowsMap:(BOOL)showsMap animated:(BOOL)animated
{
    if (_showsMap != showsMap) {
        _showsMap = showsMap;

        if (_showsMap == NO) {
            if (self.showsMapFullScreen) {
                [UIView animateWithDuration:0.33
                                 animations:^{
                                     [self setShowsMapFullScreen:NO animated:NO];

                                     _mapViewAspectHeightConstraint.priority = UILayoutPriorityDefaultLow;
                                     _mapViewFullScreenHeightConstraint.priority = UILayoutPriorityDefaultHigh;
                                     _mapViewFullScreenHeightConstraint.constant = CGRectGetHeight(self.view.bounds);

                                     [self.view setNeedsUpdateConstraints];
                                     [self.view setNeedsLayout];
                                     [self.view layoutIfNeeded];

                                     [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationTop];
                                     [self recenterMapView];
                                 }];
            }
        } else {
            [UIView animateWithDuration:0.33
                             animations:^{
                                 _mapViewFullScreenHeightConstraint.priority = UILayoutPriorityDefaultLow;
                                 _mapViewAspectHeightConstraint.priority = UILayoutPriorityDefaultHigh;
                                 _mapViewAspectHeightConstraint.constant = 0;

                                 [self.view setNeedsUpdateConstraints];
                                 [self.view setNeedsLayout];
                                 [self.view layoutIfNeeded];

                                 [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationTop];
                                 [self recenterMapView];
                             }];

        }
    }
}

- (void)setShowsMapFullScreen:(BOOL)showsMapFullScreen
{
    [self setShowsMapFullScreen:showsMapFullScreen animated:NO];
}

- (void)setShowsMapFullScreen:(BOOL)showsMapFullScreen animated:(BOOL)animated
{
    if (_showsMapFullScreen != showsMapFullScreen) {
        _showsMapFullScreen = showsMapFullScreen;


        if (_showsMapFullScreen) {
            [self willShowMapFullScreen:animated];
            [UIView animateWithDuration:0.33
                             animations:^{
                                 self.mapView.layer.transform = CATransform3DIdentity;
                                 _mapViewAspectHeightConstraint.priority = UILayoutPriorityDefaultLow;
                                 _mapViewFullScreenHeightConstraint.priority = UILayoutPriorityDefaultHigh;
                                 _mapViewFullScreenHeightConstraint.constant = CGRectGetHeight(self.tableView.frame);

                                 CGFloat mapHeight = CGRectGetHeight(self.mapView.frame);
                                 CGFloat tableViewHeight = CGRectGetHeight(self.tableView.frame);
                                 self.tableView.layer.transform = CATransform3DMakeTranslation(0., (tableViewHeight - mapHeight), 0);

                                 [self.view setNeedsUpdateConstraints];
                                 [self.view setNeedsLayout];
                                 [self.view layoutIfNeeded];
                             } completion:^(BOOL finished) {
                                 self.tableView.userInteractionEnabled = NO;
                                 self.mapView.userInteractionEnabled = YES;

                                 [self didShowMapFullScreen:animated];
                             }];
        } else {
            [self willHideMapFullScreen:animated];
            [UIView animateWithDuration:0.33
                             animations:^{
                                 self.mapView.layer.transform = CATransform3DIdentity;
                                 self.tableView.layer.transform = CATransform3DIdentity;

                                 _mapViewFullScreenHeightConstraint.priority = UILayoutPriorityDefaultLow;
                                 _mapViewAspectHeightConstraint.priority = UILayoutPriorityDefaultHigh;
                                 _mapViewAspectHeightConstraint.constant = 0;

                                 [self.view setNeedsUpdateConstraints];
                                 [self.view setNeedsLayout];
                                 [self.view layoutIfNeeded];
                             } completion:^(BOOL finished) {
                                 self.tableView.userInteractionEnabled = YES;
                                 self.mapView.userInteractionEnabled = NO;

                                 [self didHideMapFullScreen:animated];
                             }];
        }
    }
}

#pragma mark Delegate Pass-through
- (void)willShowMapFullScreen:(BOOL)animated
{
    if ([self.delegate respondsToSelector:@selector(resourceViewControllerWillShowFullScreenMap:)]) {
        [self.delegate resourceViewControllerWillShowFullScreenMap:self];
    }
}

- (void)didShowMapFullScreen:(BOOL)animated
{

    if ([self.delegate respondsToSelector:@selector(resourceViewControllerDidShowFullScreenMap:)]) {
        [self.delegate resourceViewControllerDidShowFullScreenMap:self];
    }
}

- (void)willHideMapFullScreen:(BOOL)animated
{
    if ([self.delegate respondsToSelector:@selector(resourceViewControllerWillHideFullScreenMap:)]) {
        [self.delegate resourceViewControllerWillHideFullScreenMap:self];
    }
}

- (void)didHideMapFullScreen:(BOOL)animated
{
    if ([self.delegate respondsToSelector:@selector(resourceViewControllerDidHideFullScreenMap:)]) {
        [self.delegate resourceViewControllerDidHideFullScreenMap:self];
    }
}

- (void)didSelectResource:(MITMobiusResource*)resource
{
    [self didSelectResources:@[resource]];
}

- (void)didSelectResources:(NSArray*)resources
{
    if ([self.delegate respondsToSelector:@selector(resourcesViewController:didSelectResourcesWithFetchRequest:)]) {
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[MITMobiusResource entityName]];
        NSArray *resourcesObjectIDs = [resources valueForKey:@"identifier"];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"identifier IN %@",resourcesObjectIDs];
        [self.delegate resourcesViewController:self didSelectResourcesWithFetchRequest:fetchRequest];
    }
}

#pragma mark UI updating & gesture handling
- (IBAction)handleShowMapFullScreenGesture:(UITapGestureRecognizer*)tapGesture
{
    if (tapGesture.state == UIGestureRecognizerStateEnded) {
        if (self.showsMapFullScreen == NO) {
            CGPoint tapLocation = [tapGesture locationInView:self.view];
            if (CGRectContainsPoint(self.mapView.frame, tapLocation)) {
                [self setShowsMapFullScreen:YES animated:YES];
            }
        }
    }
}

- (void)setLoading:(BOOL)loading
{
    [self setLoading:loading animated:NO];
}

- (void)setLoading:(BOOL)loading animated:(BOOL)animated
{
    if (_loading != loading) {
        _loading = loading;

        [self.tableView reloadData];
    }
}

#pragma mark UI Actions
- (IBAction)tableViewHandleSectionHeaderTap:(UIButton*)sender
{
    NSNumber *sectionIndex = [_sectionNumberByButton objectForKey:sender];
    if (sectionIndex) {
        NSUInteger section = [sectionIndex integerValue];
        MITMobiusResourcesTableSection *tableSection = self.sections[section];

        self.selectedResources = tableSection.resources;
        [self didSelectResources:tableSection.resources];
    }
}

#pragma mark - Table view data source
- (BOOL)isMapSection:(NSInteger)section
{
    return (self.showsMap && (section == 0));
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSUInteger numberOfSections = 0;
    if (self.isLoading) {
        ++numberOfSections;
    } else if (self.sections.count == 0) {
        ++numberOfSections;
    } else {
        numberOfSections = self.sections.count;
    }

    if (self.showsMap) {
        numberOfSections += 1;
    }

    return numberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([self isMapSection:section]) {
        return 1;
    } else if (self.isLoading || (self.sections.count == 0)) {
        return 1;
    } else {
        if (self.showsMap) {
            --section;
        }

        MITMobiusResourcesTableSection *tableSection = self.sections[section];
        return tableSection.resources.count;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if ([self isMapSection:section]) {
        return 0.;
    } else if (self.isLoading || (self.sections.count == 0)) {
        return 0.;
    } else {
        UITableViewHeaderFooterView *headerFooterView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:MITMobiusResourceShopHeaderReuseIdentifier];

        [self tableView:tableView configureView:headerFooterView forHeaderInSection:section];

        return [headerFooterView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
    }
}

- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if ([self isMapSection:section]) {
        return nil;
    } else if (self.isLoading || (self.sections.count == 0)) {
        return nil;
    } else {
        UITableViewHeaderFooterView *headerFooterView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:MITMobiusResourceShopHeaderReuseIdentifier];

        [self tableView:tableView configureView:headerFooterView forHeaderInSection:section];

        return headerFooterView;
    }
}

- (void)tableView:(UITableView *)tableView configureView:(UITableViewHeaderFooterView*)headerView forHeaderInSection:(NSInteger)section {
    if ([self isMapSection:section]) {
        return;
    } else {
        if (self.showsMap) {
            --section;
        }

        if ([headerView isKindOfClass:[MITMobiusShopHeader class]]) {
            static NSInteger shopButtonOverlayTag = 0xF00F;
            MITMobiusShopHeader *shopHeader = (MITMobiusShopHeader*)headerView;
            UIButton *shopButtonOverlay = (UIButton*)[shopHeader viewWithTag:shopButtonOverlayTag];
            if (!shopButtonOverlay) {
                shopButtonOverlay = [[UIButton alloc] initWithFrame:shopHeader.frame];
                shopButtonOverlay.translatesAutoresizingMaskIntoConstraints = YES;
                shopButtonOverlay.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
                [shopButtonOverlay addTarget:self action:@selector(tableViewHandleSectionHeaderTap:) forControlEvents:UIControlEventTouchUpInside];
                [shopHeader addSubview:shopButtonOverlay];
            }

            [_sectionNumberByButton setObject:@(section) forKey:shopButtonOverlay];

            MITMobiusResourcesTableSection *tableSection = self.sections[section];
            shopHeader.shopHours = tableSection.hours;
            shopHeader.shopName = tableSection.name;

            if (tableSection.isOpen) {
                shopHeader.status = MITMobiusShopStatusOpen;
            } else {
                shopHeader.status = MITMobiusShopStatusClosed;
            }
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isMapSection:indexPath.section]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MapViewCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MapViewCell"];
        }

        cell.contentView.backgroundColor = [UIColor clearColor];
        return cell;
    } else {
        if (self.isLoading) {
            MITActivityTableViewCell *cell = (MITActivityTableViewCell*)[tableView dequeueReusableCellWithIdentifier:MITMobiusResourceLoadingCellReuseIdentifier forIndexPath:indexPath];
            [cell.activityView.activityIndicatorView startAnimating];
            return cell;
        } else if (self.sections.count == 0) {
            UITableViewCell *cell = (UITableViewCell*)[tableView dequeueReusableCellWithIdentifier:MITMobiusResourceLoadingCellReuseIdentifier forIndexPath:indexPath];
            cell.textLabel.text = @"No results found";
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        } else {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MITMobiusResourceCellReuseIdentifier forIndexPath:indexPath];
            [self tableView:tableView configureCell:cell forRowAtIndexPath:indexPath];
            return cell;
        }
    }
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self isMapSection:indexPath.section]) {
        [self.view layoutIfNeeded];
        CGFloat mapHeight = CGRectGetHeight(self.mapView.frame);
        mapHeight -= _mapViewAspectHeightConstraint.constant;
        return mapHeight;
    } else if (self.isLoading) {
        return 44.;
    } else if (self.sections.count == 0) {
        return 44.;
    } else {
        return [tableView minimumHeightForCellWithReuseIdentifier:MITMobiusResourceCellReuseIdentifier atIndexPath:indexPath];
    }
}

- (void)tableView:(UITableView *)tableView configureCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isMapSection:indexPath.section]) {
        return;
    } else {
        if (self.showsMap) {
            indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
        }

        if ([cell.reuseIdentifier isEqualToString:MITMobiusResourceCellReuseIdentifier]) {
            NSAssert([cell isKindOfClass:[MITMobiusResourceTableViewCell class]], @"cell for [%@,%@] is kind of %@, expected %@",cell.reuseIdentifier,indexPath,NSStringFromClass([cell class]),NSStringFromClass([MITMobiusResourceTableViewCell class]));

            MITMobiusResourceTableViewCell *resourceTableViewCell = (MITMobiusResourceTableViewCell*)cell;
            MITMobiusResource *resource = self.sections[indexPath.section][indexPath.row];

            resourceTableViewCell.resourceView.index = NSNotFound;
            resourceTableViewCell.resourceView.machineName = resource.name;

            if ([resource.status caseInsensitiveCompare:@"online"] == NSOrderedSame) {
                [resourceTableViewCell.resourceView setStatus:MITMobiusResourceStatusOnline];
            } else if ([resource.status caseInsensitiveCompare:@"offline"] == NSOrderedSame) {
                [resourceTableViewCell.resourceView setStatus:MITMobiusResourceStatusOffline];
            } else {
                [resourceTableViewCell.resourceView setStatus:MITMobiusResourceStatusUnknown];
            }
        }
    }
}

#pragma mark UITableViewDelegate
- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self isMapSection:indexPath.section]) {
        return NO;
    } else {
        return YES;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!(self.isLoading || self.sections.count == 0)) {
        if (self.showsMap) {
            indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
        }

        MITMobiusResource *resource = self.sections[indexPath.section][indexPath.row];
        self.selectedResource = resource;
        [self didSelectResource:resource];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == self.tableView) {
        [self updateMapWithContentOffset:scrollView.contentOffset];
    }
}

#pragma mark MITCalloutViewDelegate
- (void)calloutView:(MITCalloutView *)calloutView positionedOffscreenWithOffset:(CGPoint)offset
{
    /* Do Nothing */
}

- (void)calloutViewTapped:(MITCalloutView *)calloutView
{
    [self didSelectResources:self.selectedResources];
}

- (void)calloutViewRemovedFromViewHierarchy:(MITCalloutView *)calloutView
{
    /* Do Nothing */
}

#pragma mark MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MITMobiusResourcesTableSection class]]) {
        MITMapPlaceAnnotationView *annotationView = (MITMapPlaceAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:MITMobiusResourceRoomAnnotationReuseIdentifier];
        if (!annotationView) {
            annotationView = [[MITMapPlaceAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:MITMobiusResourceRoomAnnotationReuseIdentifier];
        }

        MITMobiusResourcesTableSection *room = (MITMobiusResourcesTableSection *)annotation;
        NSUInteger index = [self.sections indexOfObject:room] + 1;
        [annotationView setNumber:index];

        return annotationView;
    }

    return nil;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    MITMobiusResourcesTableSection *mapObject = (MITMobiusResourcesTableSection*)(view.annotation);
    self.selectedResources = mapObject.resources;

    MITMobiusCalloutContentView *contentView = [[MITMobiusCalloutContentView alloc] init];
    contentView.roomName = mapObject.title;
    contentView.backgroundColor = [UIColor clearColor];

    MITMobiusResource *resource = [mapObject.resources firstObject];
    NSMutableString *machineList = [[NSMutableString alloc] initWithString:resource.name];
    if (mapObject.resources.count > 1) {
        [machineList appendFormat:@" + %ld more", (unsigned long)(mapObject.resources.count - 1)];
    }

    contentView.machineList = machineList;

    if (!self.calloutView) {
        MITCalloutView *calloutView = [[MITCalloutView alloc] init];
        calloutView.delegate = self;
        calloutView.permittedArrowDirections = MITCalloutPermittedArrowDirectionAny;

        self.mapView.mapView.mitCalloutView = calloutView;
        self.calloutView = calloutView;
    }

    self.calloutView.contentView = contentView;
    self.calloutView.contentViewPreferredSize = [contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    [self.calloutView presentFromRect:view.bounds inView:view withConstrainingView:self.mapView];
}

- (void)mapView:(MKMapView *)mapView didChangeUserTrackingMode:(MKUserTrackingMode)mode animated:(BOOL)animated
{
    if (mode == MKUserTrackingModeNone) {
        mapView.showsUserLocation = NO;
        [self recenterMapView];
    }
}

- (void)mapView:(MKMapView *)mapView didFailToLocateUserWithError:(NSError *)error
{
    mapView.userTrackingMode = MKUserTrackingModeNone;
    mapView.showsUserLocation = NO;
    [self recenterMapView];
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view
{
    [self.calloutView dismissCallout];
    self.selectedResources = nil;
}

@end