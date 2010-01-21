#import <UIKit/UIKit.h>
#import "ARGeoViewController.h"
#import "PropertyArGeoCoordinate.h"
#import "PropertySummary.h"
#import "PropertyResultsDataSource.h"
#import "PropertyResultsDelegate.h"

@protocol ARPropViewDelegate

- (UIView *)viewForCoordinate:(ARCoordinate *)coordinate;
- (void)onARControllerClose;

@end


@interface PropertyArViewController : ARGeoViewController
{
    @private
        id <PropertyResultsDataSource> propertyDataSource_;
        id <PropertyResultsDelegate> propertyDelegate_;
        UIImagePickerController *imgController_;
    
        id propdelegate_;
        UIImagePickerController *camera_;
        UIImageView *popupView_;
        UIActivityIndicatorView *progressView_;
        UIView *locationLayerView_;
        NSMutableArray *locationViews_;
        NSArray *locationItems_;
        NSMutableArray *baseItems_;
        PropertyArGeoCoordinate *selectedPoint_;
        BOOL recalibrateProximity_;
        BOOL popupIsAdded_;
        BOOL updatedLocations_;
        BOOL shouldChangeHighlight_;
        double minDistance_;
        NSInteger currentPage_;
        NSInteger contentType_;
}

@property (nonatomic, assign) IBOutlet id <PropertyResultsDataSource> propertyDataSource;
@property (nonatomic, assign) IBOutlet id <PropertyResultsDelegate> propertyDelegate;
@property (nonatomic, assign) UIImagePickerController *imgController;

@property (nonatomic, assign) id propdelegate;
@property (nonatomic, retain) UIImagePickerController *camera;
@property (nonatomic, assign) double minDistance;

- (void)addGeocodedProperty:(PropertySummary *)property atIndex:(NSInteger)index;

- (void)startListening;
- (void)updateLocations;
- (CGPoint)pointInView:(UIView *)realityView forCoordinate:(ARCoordinate *)coordinate;
- (BOOL)viewportContainsCoordinate:(ARCoordinate *)coordinate;
- (bool)isNearCoordinate:(PropertyArGeoCoordinate *)coord newCoordinate:(PropertyArGeoCoordinate *)newCoord;
- (void)updateProximityLocations;
- (void)makePanel;

@end
