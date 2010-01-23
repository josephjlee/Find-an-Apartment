#import "PropertyArViewController.h"

#define VIEWPORT_WIDTH_RADIANS .7392
#define VIEWPORT_HEIGHT_RADIANS .5

@interface PropertyArViewController ()
@property (nonatomic, retain) UIImageView *popupView;
@property (nonatomic, retain) UIActivityIndicatorView *progressView;
@property (nonatomic, retain) UIView *locationLayerView;
@property (nonatomic, retain) NSMutableArray *locationViews;
@property (nonatomic, retain) NSMutableArray *locationItems;
@property (nonatomic, retain) NSMutableArray *baseItems;
@property (nonatomic, retain) PropertyArGeoCoordinate *selectedPoint;
@property (nonatomic, assign) BOOL popupIsAdded;
@property (nonatomic, assign) BOOL updatedLocations;
@property (nonatomic, assign) BOOL shouldChangeHighlight;
@property (nonatomic, assign) BOOL recalibrateProximity;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger contentType;

- (bool)isNearCoordinate:(PropertyArGeoCoordinate *)coord newCoordinate:(PropertyArGeoCoordinate *)newCoord;
- (void)updateLocationViews;
- (void)updateProximityLocations;
- (void)makePanel;
@end


@implementation PropertyArViewController

@synthesize propertyDataSource = propertyDataSource_;
@synthesize propertyDelegate = propertyDelegate_;
@synthesize imgController = imgController_;

@synthesize propdelegate = propdelegate_;
@synthesize camera = camera_;
@synthesize popupView = popupView_;
@synthesize progressView = progressView_;
@synthesize locationLayerView = locationLayerView_;
@synthesize locationViews = locationViews_;
@synthesize locationItems = locationItems_;
@synthesize baseItems = baseItems_;
@synthesize selectedPoint = selectedPoint_;
@synthesize recalibrateProximity = recalibrateProximity_;
@synthesize popupIsAdded = popupIsAdded_;
@synthesize updatedLocations = updatedLocations_;
@synthesize shouldChangeHighlight = shouldChangeHighlight_;
@synthesize minDistance = minDistance_;
@synthesize currentPage = currentPage_;
@synthesize contentType = contentType_;

- (id)init
{
    if ((self = [super init]))
    {
        CLLocation *newCenter = [[CLLocation alloc] initWithLatitude:0 longitude:0];        
        [self setCenterLocation:newCenter];
        [newCenter release];
    }
    
    return self;
}

- (void)dealloc
{
    [camera_ release];
    [popupView_ release];
    [progressView_ release];
    [locationLayerView_ release];
    [locationViews_ release];
    [locationItems_ release];
    [baseItems_ release];
    [selectedPoint_ release];
    
    [super dealloc];
}

- (IBAction)clickedButton:(id)sender
{
    UIButton *button = (UIButton *)sender;
    [[self propertyDelegate] view:[self view] didSelectPropertyAtIndex:[button tag]];
    
    
    [[self camera] dismissModalViewControllerAnimated:YES];
}

- (void)addGeocodedProperty:(PropertySummary *)property atIndex:(NSInteger)index
{
    [self setRecalibrateProximity:YES];

    CLLocation *location = [[CLLocation alloc] initWithLatitude:[[property latitude] doubleValue]
                                                      longitude:[[property longitude] doubleValue]];
    PropertyArGeoCoordinate *geoCoordinate = [PropertyArGeoCoordinate coordinateWithLocation:location];
    [location release];

    [geoCoordinate setTitle:[property title]];
    [geoCoordinate setSubtitle:[property subtitle]];
    [geoCoordinate setSummary:[property summary]];
    [geoCoordinate setPrice:[[property price] description]];
    [geoCoordinate setIsMultiple:false];
    [geoCoordinate setViewSet:false];    
    [geoCoordinate calibrateUsingOrigin:[self centerLocation]];
    
    if ([geoCoordinate radialDistance] < [self minDistance])
    {
        [self setMinDistance:[geoCoordinate radialDistance]];
    }
    
    if ([self locationItems] == nil)
    {
        NSMutableArray *locationItems = [[NSMutableArray alloc] init];
        [self setLocationItems:locationItems];
        [locationItems release];
    }
    
    BOOL nearCoordinate = NO;
    for (NSUInteger i = 0; i < [[self locationItems] count] && !nearCoordinate; i++)
    {
        PropertyArGeoCoordinate *coord = [[self locationItems] objectAtIndex:i];
        // if the coordinates are nearby, add coordinate as a subset.
        if ([self isNearCoordinate:coord newCoordinate:geoCoordinate])
        {
            if (![coord isMultiple])
            {
                [coord setIsMultiple:true];
                CLLocation *location = [[CLLocation alloc] initWithLatitude:coord.geoLocation.coordinate.latitude
                                                                  longitude:coord.geoLocation.coordinate.longitude];
                
                PropertyArGeoCoordinate *newGeoCoordinate = [PropertyArGeoCoordinate coordinateWithLocation:location];
                [location release];
                [newGeoCoordinate setTitle:[coord title]];
                [newGeoCoordinate setIsMultiple:false];
                
                NSMutableArray *subLocations = [[NSMutableArray alloc] init];
                [subLocations addObject:newGeoCoordinate];
                [newGeoCoordinate release];
                
                [coord setSubLocations:subLocations];
                [subLocations release];
            }
            
            [[coord subLocations] addObject:geoCoordinate];
            nearCoordinate = YES;
        }
    }
    
    if (!nearCoordinate)
    {
        [[self locationItems] addObject:geoCoordinate];
    }
    
    [self updateLocationViews];
}

- (void)updateLocationViews
{
    for (UIView *view in [[self locationLayerView] subviews])
    {
        [view removeFromSuperview];
    }

    [[self locationViews] removeAllObjects];
    for (PropertyArGeoCoordinate *coordinate in [self locationItems])
    {
        if ([[self propdelegate] respondsToSelector:@selector(viewForCoordinate:)])
        {
            [[self locationViews] addObject:[[self propdelegate] viewForCoordinate:coordinate]];
        }
    }
    
    [self setUpdatedLocations:YES];  
}

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{    
    [self setPopupIsAdded:NO];
    [self setUpdatedLocations:NO];
    [self setShouldChangeHighlight:YES];
    [self setRecalibrateProximity:NO];
    [self setContentType:0];
    [self setMinDistance:1000.0];
    [self setCurrentPage:1];

    // TODO: Content view is unnecessary? Just use view
    UIView *contentView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    [contentView setBackgroundColor:[UIColor clearColor]];
    
    UIView *locationLayerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    [self setLocationLayerView:locationLayerView];
    [locationLayerView release];
    [contentView addSubview:locationLayerView];
    
    CLLocationCoordinate2D location;
    location.latitude = [[self centerLocation] coordinate].latitude;
    location.longitude = [[self centerLocation] coordinate].longitude;
    
    UIImageView *tabView  = [[UIImageView alloc] initWithFrame:CGRectMake(0, 427, 320, 55)];
    [tabView setImage:[UIImage imageNamed:@"arTabbar.png"]];
    [contentView addSubview:tabView];
    [tabView release];
    
    UIButton *doneButton = [[UIButton alloc] initWithFrame:CGRectMake(10, 440, 73, 29)];
    [doneButton setImage:[UIImage imageNamed:@"arDoneButton.png"] forState:UIControlStateNormal];
    [doneButton addTarget:self action:@selector(doneClick:) forControlEvents:(UIControlEvents)UIControlEventTouchUpInside]; 
    [contentView addSubview:doneButton];
    [doneButton release];
    
    PropertyArGeoCoordinate *selectedPoint = [[PropertyArGeoCoordinate alloc] init];
    [self setSelectedPoint:selectedPoint];
    [selectedPoint release];
    
    [self setView:contentView];
    [contentView release];
}

- (void)doneClick:(id)sender
{    
    if ([[self propdelegate] respondsToSelector:@selector(onARControllerClose)])
    {
        [[self propdelegate] onARControllerClose];
    }
    
    [[self camera] dismissModalViewControllerAnimated:NO];
}

- (BOOL)viewportContainsCoordinate:(ARCoordinate *)coordinate
{
    double centerAzimuth = self.centerCoordinate.azimuth;
    double leftAzimuth = centerAzimuth - VIEWPORT_WIDTH_RADIANS / 2.0;
    
    if (leftAzimuth < 0.0)
    {
        leftAzimuth = 2 * M_PI + leftAzimuth;
    }
    
    double rightAzimuth = centerAzimuth + VIEWPORT_WIDTH_RADIANS / 2.0;
    
    if (rightAzimuth > 2 * M_PI)
    {
        rightAzimuth = rightAzimuth - 2 * M_PI;
    }
    
    BOOL result = (coordinate.azimuth > leftAzimuth && coordinate.azimuth < rightAzimuth);
    
    if (leftAzimuth > rightAzimuth)
    {
        result = (coordinate.azimuth < rightAzimuth || coordinate.azimuth > leftAzimuth);
    }
    
    double centerInclination = self.centerCoordinate.inclination;
    double bottomInclination = centerInclination - VIEWPORT_HEIGHT_RADIANS / 2.0;
    double topInclination = centerInclination + VIEWPORT_HEIGHT_RADIANS / 2.0;
    
    //check the height.
    result = result && (coordinate.inclination > bottomInclination && coordinate.inclination < topInclination);
    
    return result;
}

- (void)startListening
{
    
    //start our heading readings and our accelerometer readings.
    if ([self locationManager] == nil)
    {
        [self setLocationManager:[[[CLLocationManager alloc] init] autorelease]];
        
        //we want every move.
        [[self locationManager] setHeadingFilter:kCLHeadingFilterNone];
        
        [[self locationManager] startUpdatingHeading];
        [[self locationManager] setDelegate:self];
        [[self locationManager] setDistanceFilter:200];  // .1 miles
        [[self locationManager] setDesiredAccuracy:kCLLocationAccuracyBest];
        [[self locationManager] startUpdatingLocation];
    }
    
    if ([self accelerometerManager] == nil)
    {
        [self setAccelerometerManager:[UIAccelerometer sharedAccelerometer]];
        [[self accelerometerManager] setUpdateInterval:0.04];
        [[self accelerometerManager] setDelegate:self];
    }
    
    if ([self centerCoordinate] == nil)
    {
        [self setCenterCoordinate:[ARCoordinate coordinateWithRadialDistance:0 inclination:0 azimuth:0]];
    }
}

// Delegate method from the CLLocationManagerDelegate protocol.
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{    
    self.centerLocation = newLocation;
    
    //MKCoordinateSpan span;
    //span.latitudeDelta = 0.01;
    //span.longitudeDelta = 0.01;
    CLLocationCoordinate2D theLocation;
    theLocation.latitude = self.centerLocation.coordinate.latitude;
    theLocation.longitude = self.centerLocation.coordinate.longitude;
    
    if ([self recalibrateProximity])
    {
        [self setRecalibrateProximity:NO];
        [self updateProximityLocations];
    }
    
    for (PropertyArGeoCoordinate *geoLocation in self.locationItems)
    {
        if ([geoLocation isKindOfClass:[PropertyArGeoCoordinate class]])
        {
            [geoLocation calibrateUsingOrigin:centerLocation];
        }
    }
    
    [self updateLocations];
}

- (void) updateProximityLocations
{
    for (PropertyArGeoCoordinate *geoCoordinate in [self locationItems])
    {
        [geoCoordinate.subLocations release];
        geoCoordinate.isMultiple = false;
        [geoCoordinate calibrateUsingOrigin:centerLocation];
        
        if ([geoCoordinate radialDistance] < [self minDistance])
        {
            [self setMinDistance:[geoCoordinate radialDistance]];
        }
        
        [self updateLocationViews];
    }
}

- (bool)isNearCoordinate:(PropertyArGeoCoordinate *)coord newCoordinate:(PropertyArGeoCoordinate *)newCoord
{
    bool isNear = true;
    float baseRange = .0015;
    float range = baseRange * coord.radialDistance;
    
    if ((newCoord.geoLocation.coordinate.latitude > (coord.geoLocation.coordinate.latitude + range)) ||
       (newCoord.geoLocation.coordinate.latitude < (coord.geoLocation.coordinate.latitude - range)))
    {
        isNear = false;
    }
    if ((newCoord.geoLocation.coordinate.longitude > (coord.geoLocation.coordinate.longitude + range)) ||
       (newCoord.geoLocation.coordinate.longitude < (coord.geoLocation.coordinate.longitude - range)))
    {
        isNear = false;
    }
    
    return isNear;
}

- (CGPoint)pointInView:(UIView *)realityView forCoordinate:(ARCoordinate *)coordinate
{
    
    CGPoint point;
    
    //x coordinate.
    
    double pointAzimuth = coordinate.azimuth;
    
    //our x numbers are left based.
    double leftAzimuth = [[self centerCoordinate] azimuth] - VIEWPORT_WIDTH_RADIANS / 2.0;
    
    if (leftAzimuth < 0.0)
    {
        leftAzimuth = 2 * M_PI + leftAzimuth;
    }
    
    if (pointAzimuth < leftAzimuth)
    {
        //it's past the 0 point.
        point.x = ((2 * M_PI - leftAzimuth + pointAzimuth) / VIEWPORT_WIDTH_RADIANS) * [realityView frame].size.height;
    }
    else
    {
        
        point.x = ((pointAzimuth - leftAzimuth) / VIEWPORT_WIDTH_RADIANS) * [realityView frame].size.height;
    }
    
    //y coordinate.
    
    double pointInclination = [coordinate inclination];
    double topInclination = [[self centerCoordinate] inclination] - VIEWPORT_HEIGHT_RADIANS / 2.0;
    
    // changing from width to height on the reality frame to account for portrait.
    point.y = [realityView frame].size.height - ((pointInclination - topInclination) / VIEWPORT_HEIGHT_RADIANS) * [realityView frame].size.height;
    
    return point;
}

#define kFilteringFactor 0.05
UIAccelerationValue rollingX, rollingZ;

- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration
{
    // -1 face down.
    // 1 face up.
    
    //update the center coordinate.
    
    // trying to reverse it here.. changed x to acceleration.y..
    
    rollingX = (acceleration.y * kFilteringFactor) + (rollingX * (1.0 - kFilteringFactor));
    rollingZ = (acceleration.z * kFilteringFactor) + (rollingZ * (1.0 - kFilteringFactor));
    
    if (rollingX > 0.0)
    {
        [[self centerCoordinate] setInclination:- atan(rollingZ / rollingX) - M_PI];
    }
    else if (rollingX < 0.0)
    {
        [[self centerCoordinate] setInclination:- atan(rollingZ / rollingX)];// + M_PI];
    }
    else if (rollingZ < 0)
    {
        [[self centerCoordinate] setInclination:M_PI/2.0];
    }
    else if (rollingZ >= 0)
    {
        [[self centerCoordinate] setInclination:3 * M_PI/2.0];
    }
    
    [self updateLocations];
}

NSComparisonResult LocationSortFarthesttFirst(ARCoordinate *s1, ARCoordinate *s2, void *ignore)
{
    if ([s1 radialDistance] < [s2 radialDistance])
    {
        return NSOrderedAscending;
    }
    else if ([s1 radialDistance] > [s2 radialDistance])
    {
        return NSOrderedDescending;
    }
    else
    {
        return NSOrderedSame;
    }
}

- (void)updateLocations
{    
    if ([[self locationItems] count] < 25 && [self progressView] == nil)
    {
        
        UIActivityIndicatorView *progressView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(10, 10, 320, 480)];
        [self setProgressView:progressView];
        [progressView release];
        
        [[self progressView] startAnimating];
        [[self progressView] setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhite];
        [[self progressView] sizeToFit];
        
        [[self view] addSubview:[self progressView]];
        
    }
    else if ([[self locationItems] count] >= 25)
    {
        [[self progressView] removeFromSuperview];
    }
    
    for (NSUInteger i = 0; i < [[self locationItems] count]; i++)
    {
        PropertyArGeoCoordinate *item = [[self locationItems] objectAtIndex:i];
        UIImageView *viewToDraw = [[self locationViews] objectAtIndex:i];
        
        NSString *image = @"arPropertyButton.png";
        if (self.selectedPoint != nil)
        {
            if (item.geoLocation.coordinate.latitude == self.selectedPoint.geoLocation.coordinate.latitude && 
               item.geoLocation.coordinate.longitude == self.selectedPoint.geoLocation.coordinate.longitude)
            {
                image = @"arSelectedPropertyButton.png";
                
                if (item.isMultiple)
                {
                    image = @"arSelectedPropertiesButton.png";
                }
            }
            else 
            {
                if (item.isMultiple)
                {
                    image = @"arPropertiesButton.png";
                    
                    for (PropertyArGeoCoordinate *coord in item.subLocations)
                    {
                        if (coord.geoLocation.coordinate.latitude == self.selectedPoint.geoLocation.coordinate.latitude && 
                           coord.geoLocation.coordinate.longitude == self.selectedPoint.geoLocation.coordinate.longitude)
                        {
                            image = @"arSelectedPropertiesButton.png";
                        }
                    }
                }
            }
        }
        
        NSInteger tag = 0;
        if ([item isMultiple])
        {
            tag = 1;
        }
        
        UIImage *img = [UIImage imageNamed:image];
        [viewToDraw setImage:img];
        [viewToDraw setTag:tag];
        
        if ([self viewportContainsCoordinate:item])
        {
            CGPoint loc = [self pointInView:self.view forCoordinate:item];
            
            float width = [viewToDraw frame].size.width;
            float height = [viewToDraw frame].size.height;
            
            viewToDraw.frame = CGRectMake(loc.x - width / 2.0, loc.y - width / 2.0, width, height);
            
            [self.locationLayerView addSubview:viewToDraw];
        }
        else
        {    
            [viewToDraw removeFromSuperview];
        }
    }
}

#define BOX_WIDTH 200
#define BOX_HEIGHT 68

- (UIView *)viewForCoordinate:(PropertyArGeoCoordinate *)coordinate
{    
    [coordinate calibrateUsingOrigin:[self centerLocation]];
    
    double inclinationFactor = 33 * coordinate.radialDistance;
    
    if ([coordinate radialDistance] < .5)
    {
        inclinationFactor = 27;
    }
    
    coordinate.inclination = -M_PI/inclinationFactor + .05;
    
    CGRect frame = CGRectMake(0, 0, BOX_WIDTH, BOX_HEIGHT);
    NSString *image = @"arFinalPoint.png";
    
    UIImageView *imageView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:image]] autorelease];
    [imageView setFrame:frame];
    [imageView setAlpha:.85];
    [imageView setUserInteractionEnabled:YES];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(7, 11, BOX_WIDTH - 10, 20.0)];
    [titleLabel setBackgroundColor:[UIColor clearColor]];
    [titleLabel setTextColor:[UIColor whiteColor]];
    [titleLabel setFont:[UIFont fontWithName:@"Helvetica" size:18]];
    [titleLabel setShadowColor:[UIColor grayColor]];
    [titleLabel setShadowOffset:CGSizeMake(1, 1)];
    [titleLabel setText:[coordinate title]];
    [imageView addSubview:titleLabel];
    [titleLabel release];
    
    UILabel *distanceLabel = [[UILabel alloc] initWithFrame:CGRectMake(7, 27, BOX_WIDTH - 10, 20.0)];
    [distanceLabel setBackgroundColor:[UIColor clearColor]];
    [distanceLabel setTextColor:[UIColor whiteColor]];
    [distanceLabel setFont:[UIFont fontWithName:@"Helvetica" size: 16]];
    [distanceLabel setShadowColor:[UIColor grayColor]];
    [distanceLabel setShadowOffset:CGSizeMake(1, 1)];
    [distanceLabel setText:[NSString stringWithFormat:@"%.1f miles", [coordinate radialDistance]]];
    [imageView addSubview:distanceLabel];
    [distanceLabel release];
    
    return imageView;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    // former: add 90 to trueHeading
    [[self centerCoordinate] setAzimuth:fmod(newHeading.trueHeading, 360.0) * (2 * (M_PI / 360.0))];
    [self updateLocations];
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager *)manager
{
    return YES;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    
    BOOL found = NO;
    for (NSUInteger i = 0; i < [[self locationViews] count] && !found; i++)
    {
        UIView *item = [[self locationViews] objectAtIndex:i];
        if ([touch view] == item)
        {
            [self setCurrentPage:1];
            [self setSelectedPoint:(PropertyArGeoCoordinate *)[[self locationItems] objectAtIndex:i]];
            
            [self makePanel];
            
            [UIView beginAnimations:nil context:@"some-identifier-used-by-a-delegate-if-set"];
            [UIView setAnimationDelegate:self];
            [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
            [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
            [UIView setAnimationDuration:0.4f];
            
            double topPoint = 210.0f;
            if ([self contentType] == 2)
            {
                topPoint = 130.0f;
            }
            else if ([self contentType] == 1)
            {
                topPoint = 171.0f;
            }
            
            CGRect frame = [[self popupView] frame];
            frame.origin.y = topPoint;
            self.popupView.frame = frame;
            
            [self setPopupIsAdded:YES];
            [UIView commitAnimations];
            
            found = YES;
        }
    }
}

- (void)nextPanel:(id)sender
{
    NSInteger i = 0;
    NSInteger currentIndex = 0;
    for (i = 0; i < (NSInteger)[[[self selectedPoint] subLocations] count]; i++)
    {
        PropertyArGeoCoordinate *coord = [[[self selectedPoint] subLocations] objectAtIndex:i];
        if (coord.geoLocation.coordinate.latitude == self.selectedPoint.geoLocation.coordinate.latitude && 
           coord.geoLocation.coordinate.longitude == self.selectedPoint.geoLocation.coordinate.longitude
           && [coord title] == [[self selectedPoint] title])
        {
            currentIndex = i + 1;
        }
    }
    
    [self setCurrentPage:[self currentPage] + 1];
    if (currentIndex > i - 1)
    {
        [self setCurrentPage:1];
        currentIndex = 0;
    }
    
    NSMutableArray *subLocations = [[[self selectedPoint] subLocations] mutableCopy];
    [self setSelectedPoint:(PropertyArGeoCoordinate *)[subLocations objectAtIndex:currentIndex]];
    [[self selectedPoint] setSubLocations:subLocations];
    [subLocations release];
    [[self selectedPoint] calibrateUsingOrigin:[self centerLocation]];

    [self setShouldChangeHighlight:NO];
    
    [self makePanel];
}

- (void)previousPanel:(id)sender
{
    NSInteger i = 0;
    NSInteger currentIndex = 0;
    for (i = 0; i < (NSInteger)[[[self selectedPoint] subLocations] count]; i++)
    {
        PropertyArGeoCoordinate *coord = [[[self selectedPoint] subLocations] objectAtIndex:i];        
        if (coord.geoLocation.coordinate.latitude == self.selectedPoint.geoLocation.coordinate.latitude && 
           coord.geoLocation.coordinate.longitude == self.selectedPoint.geoLocation.coordinate.longitude
           && coord.title == self.selectedPoint.title)
        {
            currentIndex = i - 1;
        }
    }
    
    [self setCurrentPage:[self currentPage] - 1];
    if (currentIndex < 0)
    {
        [self setCurrentPage:i];
        currentIndex = i - 1;
    }

    NSMutableArray *subLocations = [[[self selectedPoint] subLocations] mutableCopy];
    [self setSelectedPoint:(PropertyArGeoCoordinate *)[subLocations objectAtIndex:currentIndex]];
    [[self selectedPoint] setSubLocations:subLocations];
    [subLocations release];
    [[self selectedPoint] calibrateUsingOrigin:[self centerLocation]];
    
    [self setShouldChangeHighlight:NO];
    
    [self makePanel];
}

- (void)makePanel 
{    
    if ([self popupIsAdded])
    {
        if ([self popupView] != nil)
        {
            [[self popupView] removeFromSuperview];
            [[self popupView] release];
        }
    }
    
    NSInteger topPoint = 500;
    if ([self popupIsAdded])
    {
        topPoint = 210;
    }
    
    UIImageView *popupView = [[UIView alloc] initWithFrame:CGRectMake(14, topPoint, 292, 215)];
    [self setPopupView:popupView];
    [popupView release];
    
    [[self view] addSubview:[self popupView]];
    [self setPopupIsAdded:YES];
    
    NSInteger buttonStart = 19;
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 292, 215)];
    [imageView setImage:[UIImage imageNamed:@"arPopupBackground.png"]];
    [[self popupView] addSubview:imageView];
    [imageView release];
    
    UILabel *titleText = [[UILabel alloc] initWithFrame:CGRectMake(19, 10, 270, 26)];
    [titleText setText:[[self selectedPoint] title]];
    [titleText setShadowColor:[UIColor grayColor]];
    [titleText setShadowOffset:CGSizeMake(1, 1)];
    [titleText setFont:[UIFont fontWithName:@"Helvetica" size: 20]];
    [titleText setTextColor:[UIColor whiteColor]];
    [titleText setBackgroundColor:[UIColor clearColor]];
    [[self popupView] addSubview:titleText];
    [titleText release];
    
    UILabel *distanceText = [[UILabel alloc] initWithFrame:CGRectMake(19, 32, 270, 20)];
    [distanceText setText:[NSString stringWithFormat:@"%.1f miles", [[self selectedPoint] radialDistance]]];
    [distanceText setFont:[UIFont fontWithName:@"Helvetica" size:16]];
    [distanceText setTextColor:[UIColor whiteColor]];
    [distanceText setBackgroundColor:[UIColor clearColor]];
    [[self popupView] addSubview:distanceText];
    [distanceText release];

    if ([[self selectedPoint] subtitle] != nil)
    {
        UILabel *subtitleText = [[UILabel alloc] initWithFrame:CGRectMake(19, 65, 270, 18)];
        [subtitleText setText:[[self selectedPoint] subtitle]];
        [subtitleText setFont:[UIFont fontWithName:@"Helvetica" size: 16]];
        [subtitleText setTextColor:[UIColor whiteColor]];
        [subtitleText setBackgroundColor:[UIColor clearColor]];
        [[self popupView] addSubview:subtitleText];
        [subtitleText release];
    }

    if ([[self selectedPoint] summary] != nil)
    {
        UILabel *summaryText = [[UILabel alloc] initWithFrame:CGRectMake(19, 85, 270, 18)];
        [summaryText setText:[NSString stringWithFormat:@"%@", [[self selectedPoint] summary]]];
        [summaryText setFont:[UIFont fontWithName:@"Helvetica" size: 16]];
        [summaryText setTextColor:[UIColor whiteColor]];
        [summaryText setBackgroundColor:[UIColor clearColor]];
        [[self popupView] addSubview:summaryText];
        [summaryText release];
    }

    if ([[self selectedPoint] price] != nil)
    {        
        UILabel *priceText = [[UILabel alloc] initWithFrame:CGRectMake(19, 105, 270, 18)];
        [priceText setText:[NSString stringWithFormat:@"$%@", [[self selectedPoint] price]]];
        [priceText setFont:[UIFont fontWithName:@"Helvetica" size:16]];
        [priceText setTextColor:[UIColor whiteColor]];
        [priceText setBackgroundColor:[UIColor clearColor]];
        [[self popupView] addSubview:priceText];
        [priceText release];
    }
    
    UIButton *closeButton = [[UIButton alloc] initWithFrame:CGRectMake(-5, -5, 30, 28)];
    [closeButton setImage:[UIImage imageNamed:@"arPopupCloseButton.png"] forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(panelCloseClick:) forControlEvents:(UIControlEvents)UIControlEventTouchDown];
    [[self popupView] addSubview:closeButton];
    [closeButton release];
    
    // to pop the details view.
    // TODO: Why is there  an init after the UIButton is being autoreleased? Remove/change and test
    UIButton *detailsButton = [[UIButton buttonWithType:UIButtonTypeDetailDisclosure] initWithFrame:CGRectMake(250, 10, 30, 28)];
    
    // figure out the tag for the details button
    BOOL found = NO;
    NSInteger tag = 0;
    for (NSInteger i = 0; i < (NSInteger)[[self locationItems] count] && !found; i++)
    {
        PropertyArGeoCoordinate *coord = [[self locationItems] objectAtIndex:i];
        if ([[coord title] isEqual:[[self selectedPoint] title]]
            && [[coord geoLocation] coordinate].longitude == [[[self selectedPoint] geoLocation] coordinate].longitude
            && [[coord geoLocation] coordinate].latitude == [[[self selectedPoint] geoLocation] coordinate].latitude)
        {
            tag = i;
        }
    }
    
    [detailsButton setTag:tag];
    [detailsButton addTarget:self action:@selector(clickedButton:) forControlEvents:UIControlEventTouchUpInside];
    
    [[self popupView] addSubview:detailsButton];
    
    if ([[self locationItems] count] > 1)
    {
        buttonStart = 55;
    }
    
    // TODO: Can probably remove these three buttons
    UIButton *buttonCall = [[UIButton alloc] initWithFrame:CGRectMake(buttonStart, 143, 59, 62)];
    [buttonCall setImage:[UIImage imageNamed:@"Phone2.png"] forState:UIControlStateNormal];
    [buttonCall addTarget:self action:@selector(callClick:) forControlEvents:(UIControlEvents)UIControlEventTouchUpInside]; 
    [[self popupView] addSubview:buttonCall];
    [buttonCall release];
    
    buttonStart += 59;
    
    UIButton *buttonMaps = [[UIButton alloc] initWithFrame:CGRectMake(buttonStart, 143, 59, 62)];
    [buttonMaps setImage:[UIImage imageNamed:@"Maps2.png"] forState:UIControlStateNormal];
    [buttonMaps addTarget:self action:@selector(mapsClick:) forControlEvents:(UIControlEvents)UIControlEventTouchUpInside]; 
    [[self popupView] addSubview:buttonMaps];
    [buttonMaps release];
    
    buttonStart += 61;
    
    UIButton *buttonBing = [[UIButton alloc] initWithFrame:CGRectMake(buttonStart, 145, 59, 62)];
    [buttonBing setImage:[UIImage imageNamed:@"Bing2.png"] forState:UIControlStateNormal];
    [buttonBing addTarget:self action:@selector(bingClick:) forControlEvents:(UIControlEvents)UIControlEventTouchUpInside]; 
    [[self popupView] addSubview:buttonBing];
    [buttonBing release];
    
    if ([[[self selectedPoint] subLocations] count] > 1)
    {
        // TODO: Remove button start with hardcoded values
        buttonStart += 73;
        UIButton *nextArrowButton = [[UIButton alloc] initWithFrame:CGRectMake(buttonStart, 143, 50, 62)];
        [nextArrowButton setImage:[UIImage imageNamed:@"arNext.png"] forState:UIControlStateNormal];
        [nextArrowButton addTarget:self action:@selector(nextPanel:) forControlEvents:(UIControlEvents)UIControlEventTouchUpInside]; 
        [[self popupView] addSubview:nextArrowButton];
        [nextArrowButton release];
        
        buttonStart = buttonStart - 125;

        UILabel *pageNotification = [[UILabel alloc] initWithFrame:CGRectMake(buttonStart, 149, 100, 62)];
        [pageNotification setText:[NSString stringWithFormat:@"%d of %d", [self currentPage], [[[self selectedPoint] subLocations] count]]];
        [pageNotification setFont:[UIFont fontWithName:@"Helvetica" size: 16]];
        [pageNotification setTextColor:[UIColor whiteColor]];
        [pageNotification setBackgroundColor:[UIColor clearColor]];
        [[self popupView] addSubview:pageNotification];
        [pageNotification release];
        
        UIButton *previousArrowButton = [[UIButton alloc] initWithFrame:CGRectMake(-8, 143, 50, 62)];
        [previousArrowButton setImage:[UIImage imageNamed:@"arPrevious.png"] forState:UIControlStateNormal];
        [previousArrowButton addTarget:self action:@selector(previousPanel:) forControlEvents:(UIControlEvents)UIControlEventTouchUpInside]; 
        [[self popupView] addSubview:previousArrowButton];
        [previousArrowButton release];
    }
}

- (void)panelCloseClick:(id)sender
{
    [UIView beginAnimations:nil context:@"some-identifier-used-by-a-delegate-if-set"];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    [UIView setAnimationDuration:0.4f]; 

    CGRect frame = [[self popupView] frame];
    frame.origin.y = 500.0f;
    [[self popupView] setFrame:frame];
    
    [UIView commitAnimations];
    
    // TODO: What is happening here?
    [self.selectedPoint release];
    self.selectedPoint = [PropertyArGeoCoordinate alloc];
    
    for (UIImageView *imageView in [self locationViews])
    {
        if ([imageView tag] == 1)
        {
            [imageView setImage:[UIImage imageNamed:@"apts"]];
        }
        else if ([imageView tag] == 2)
        {
            [imageView setImage:[UIImage imageNamed:@"apt"]];
        }
    }
    
    [self setPopupIsAdded:NO];
}

- (void)setCenterLocation:(CLLocation *)newLocation
{
    [self setCenterLocation:newLocation];
    
    for (PropertyArGeoCoordinate *geoLocation in [self locationItems])
    {
        if ([geoLocation isKindOfClass:[PropertyArGeoCoordinate class]])
        {
            [geoLocation calibrateUsingOrigin:centerLocation];
        }
    }
}

@end
