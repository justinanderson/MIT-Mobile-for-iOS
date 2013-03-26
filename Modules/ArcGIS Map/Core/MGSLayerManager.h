#import <Foundation/Foundation.h>
#import <ArcGIS/ArcGIS.h>

@class MGSLayer;
@class MGSLayerManager;
@protocol MGSAnnotation;

@protocol MGSLayerManagerDelegate <NSObject>
- (AGSGraphicsLayer*)layerManager:(MGSLayerManager*)layerManager graphicsLayerForLayer:(MGSLayer*)layer;
- (AGSGraphic*)layerManager:(MGSLayerManager*)layerManager graphicForAnnotation:(id<MGSAnnotation>)annotation;
@end

@interface MGSLayerManager : NSObject

@property (nonatomic,readonly,strong) MGSLayer *layer;


@property (nonatomic,readonly,strong) AGSGraphicsLayer *graphicsLayer;
@property (nonatomic,strong) NSArray *graphics;
@property (nonatomic,strong) AGSSpatialReference *defaultSpatialReference;
@property (nonatomic,weak) id<MGSLayerManagerDelegate> delegate;

- (id)initWithLayer:(MGSLayer*)layer;

- (void)syncAnnotations;
- (AGSGraphic*)graphicForAnnotation:(id<MGSAnnotation>)annotation;
- (id<MGSAnnotation>)annotationForGraphic:(AGSGraphic*)graphic;
@end
