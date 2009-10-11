#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <ObjectiveLibxml2/ObjectiveLibxml2.h>

#import "Placemark.h"
#import "PropertyGeocoder.h"
#import "PropertyHistory.h"
#import "PropertySummary.h"
#import "PropertyDetailsViewController.h"


@interface PropertyMapViewController : UIViewController <PropertyDetailsDelegate, PropertyGeocoderDelegate, MKMapViewDelegate>
{
    @private
        PropertyHistory *history_;
        NSSet *summaries_;
        PropertySummary *summary_;
        MKMapView *mapView_;
        NSOperationQueue *operationQueue_;
        Placemark *placemark_;
        CLLocationCoordinate2D maxPoint_;
        CLLocationCoordinate2D minPoint_;
        BOOL isCancelled_;
        BOOL isFromFavorites_;
        NSInteger summaryIndex_;
        NSInteger selectedIndex_;
}

@property (nonatomic, retain) IBOutlet MKMapView *mapView;
@property (nonatomic, retain) PropertyHistory *history;
@property (nonatomic, retain) PropertySummary *summary;
@property (nonatomic, assign) BOOL isFromFavorites;

@end
