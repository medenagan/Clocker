//
//  CLPreferencesViewController.m
//  Clocker
//
//  Created by Abhishek Banthia on 12/12/15.
//
//

#import "CLPreferencesViewController.h"
#import "Panel.h"
#import "PanelController.h"
#import "ApplicationDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import "CommonStrings.h"
#import "Reachability.h"
#import <Parse/Parse.h>

NSString *const CLSearchPredicateKey = @"SELF CONTAINS[cd]%@";
NSString *const CLPreferencesViewNibIdentifier = @"PreferencesWindow";
NSString *const CLPreferencesTimezoneNameIdentifier = @"formattedAddress";
NSString *const CLPreferencesAbbreviationIdentifier = @"abbreviation";
NSString *const CLPreferencesCustomLabelIdentifier = @"label";
NSString *const CLPreferencesAvailableTimezoneIdentifier = @"availableTimezones";
NSString *const CLNoTimezoneSelectedErrorMessage =  @"Please select a timezone!";
NSString *const CLMaxTimezonesErrorMessage =  @"Maximum 10 timezones allowed!";
NSString *const CLTimezoneAlreadySelectedError = @"Timezone has already been selected!";
NSString *const CLParseTimezoneSelectionClassIdentifier = @"CLTimezoneSelection";
NSString *const CLParseTimezoneNameProperty = @"areaName";
NSString *const CLMaxCharactersReachedError = @"Only 50 characters allowed!";
NSString *const CLNoInternetConnectivityError = @"You're offline, maybe?";
NSString *const CLLocationSearchURL = @"https://maps.googleapis.com/maps/api/geocode/json?address=%@&key=AIzaSyCyf2knCi6KiKuDJLYDBD3Odq5dt4c-_KI";
NSString *const CLTryAgainMessage = @"Try again, maybe?";

@interface CLPreferencesViewController ()
@property (weak) IBOutlet NSTextField *placeholderLabel;
@property (assign) BOOL activityInProgress;

@property (weak) IBOutlet NSTableView *timezoneTableView;
@property (strong) IBOutlet Panel *timezonePanel;
@property (weak) IBOutlet NSSegmentedControl *theme;
@property (weak) IBOutlet NSPopUpButton *fontPopUp;
@property (weak) IBOutlet NSTableView *availableTimezoneTableView;
@property (weak) IBOutlet NSSearchField *searchField;
@property (weak) IBOutlet NSSegmentedControl *timeFormat;
@property (weak) IBOutlet NSTextField *messageLabel;

@end

@implementation CLPreferencesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CALayer *viewLayer = [CALayer layer];
    [viewLayer setBackgroundColor:CGColorCreateGenericRGB(255.0, 255.0, 255.0, 0.8)]; //RGB plus Alpha Channel
    [self.view setWantsLayer:YES];
    [self.view setLayer:viewLayer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refereshTimezoneTableView) name:CLCustomLabelChangedNotification object:nil];
    self.placeholderLabel.hidden = YES;
    
    [self refereshTimezoneTableView];
    
    if (!self.filteredArray)
    {
        self.filteredArray = [[NSMutableArray alloc] init];
    }
    
    self.messageLabel.stringValue = CLEmptyString;

    [self.availableTimezoneTableView reloadData];
    
    //Register for drag and drop
    [self.timezoneTableView registerForDraggedTypes: [NSArray arrayWithObject: CLDragSessionKey]];
    
        // Do view setup here.
}



-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:CLCustomLabelChangedNotification object:nil];
}


-(BOOL)acceptsFirstResponder
{
    return YES;
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (tableView == self.timezoneTableView)
    {
        return self.selectedTimeZones.count;
    }
    else
    {
        return self.filteredArray.count;
    }
    
    return 0;
}

- (nullable id)tableView:(NSTableView *)tableView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:CLPreferencesTimezoneNameIdentifier])
    {
        if ([self.selectedTimeZones[row][CLTimezoneName] length] > 0) {
           return self.selectedTimeZones[row][CLTimezoneName];
        }
        return self.selectedTimeZones[row][CLTimezoneID];
    }
    else if([[tableColumn identifier] isEqualToString:CLPreferencesAvailableTimezoneIdentifier])
    {
        if (row < self.filteredArray.count)
        {
            return [self.filteredArray[row] objectForKey:CLTimezoneName];
        }
        
        return nil;
    }
    else if([[tableColumn identifier] isEqualToString:CLPreferencesCustomLabelIdentifier])
    {
        return self.selectedTimeZones[row][CLCustomLabel];
    }

    return nil;
    
}

-(void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([object isKindOfClass:[NSString class]])
    {
        
        NSString *originalValue = (NSString *)object;
        NSString *customLabelValue = [originalValue stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceCharacterSet]];
        
        NSMutableDictionary *timezoneDictionary = self.selectedTimeZones[row];
        NSMutableDictionary *mutableTimeZoneDict = [timezoneDictionary mutableCopy];
        customLabelValue.length > 0 ? [mutableTimeZoneDict setValue:customLabelValue forKey:CLCustomLabel] : [mutableTimeZoneDict setValue:CLEmptyString forKey:CLCustomLabel];
        [self.selectedTimeZones replaceObjectAtIndex:row withObject:mutableTimeZoneDict];
        [[NSUserDefaults standardUserDefaults] setObject:self.selectedTimeZones forKey:CLDefaultPreferenceKey];
        
        [self refreshMainTableview];
    }
}

- (IBAction)addTimeZone:(id)sender
{
    [self.view.window beginSheet:self.timezonePanel completionHandler:nil];
}

- (IBAction)addToFavorites:(id)sender
{
    self.activityInProgress = YES;

    if (self.availableTimezoneTableView.selectedRow == -1)
    {
        self.messageLabel.stringValue = CLNoTimezoneSelectedErrorMessage;
        [NSTimer scheduledTimerWithTimeInterval:5 target:self
                                       selector:@selector(clearLabel)
                                       userInfo:nil
                                        repeats:NO];
        self.activityInProgress = NO;
        return;
    }

    NSString *selectedTimezone;
    
    if (self.selectedTimeZones.count >= 10)
    {
        self.messageLabel.stringValue = CLMaxTimezonesErrorMessage;
        [NSTimer scheduledTimerWithTimeInterval:5 target:self
                                       selector:@selector(clearLabel)
                                       userInfo:nil
                                        repeats:NO];
        self.activityInProgress = NO;
        return;
    }
    
    for (NSMutableDictionary *timezoneDictionary in self.selectedTimeZones)
    {
        NSString *name = timezoneDictionary[CLPlaceIdentifier];
        NSString *selectedPlaceID = [self.filteredArray[self.availableTimezoneTableView.selectedRow] objectForKey:CLPlaceIdentifier];
        
        if (self.searchField.stringValue.length > 0) {
            if ([name isKindOfClass:[NSString class]] &&
                [name isEqualToString:selectedPlaceID])
            {
                self.messageLabel.stringValue = CLTimezoneAlreadySelectedError;
                [NSTimer scheduledTimerWithTimeInterval:5
                                                 target:self
                                               selector:@selector(clearLabel) userInfo:nil
                                                repeats:NO];
                self.activityInProgress = NO;
                return;
            }
        }
    }
    
    selectedTimezone = self.filteredArray[self.availableTimezoneTableView.selectedRow];
    
    self.searchField.stringValue = CLEmptyString;
    
   [self getTimeZoneForLatitude:[self.filteredArray[self.availableTimezoneTableView
                                                    .selectedRow] objectForKey:@"latitude"]andLongitude:[self.filteredArray[self.availableTimezoneTableView.selectedRow] objectForKey:@"longitude"]];
    
    PFObject *feedbackObject = [PFObject objectWithClassName:CLParseTimezoneSelectionClassIdentifier];
    feedbackObject[CLParseTimezoneNameProperty] = [self.filteredArray[self.availableTimezoneTableView.selectedRow] objectForKey:CLTimezoneName];
    [feedbackObject saveEventually];

}

- (IBAction)closePanel:(id)sender
{
    self.filteredArray = [NSMutableArray array];
    self.placeholderLabel.placeholderString = CLEmptyString;
    [self.availableTimezoneTableView reloadData];
    self.searchField.stringValue = CLEmptyString;
    self.searchField.placeholderString = @"Enter a city, state or country name";
    [self.timezonePanel close];
    self.activityInProgress = NO;
}

- (void)clearLabel
{
    self.messageLabel.stringValue = CLEmptyString;
}

- (IBAction)removeFromFavourites:(id)sender
{
    NSMutableArray *itemsToRemove = [NSMutableArray array];
    
    if (self.timezoneTableView.selectedRow == -1)
    {
        return;
    }
    
    [self.timezoneTableView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        
        [itemsToRemove addObject:self.selectedTimeZones[idx]];
        
    }];
    
    [self.selectedTimeZones removeObjectsInArray:itemsToRemove];
    
    NSMutableArray *newDefaults = [[NSMutableArray alloc] initWithArray:self.selectedTimeZones];
    
    [[NSUserDefaults standardUserDefaults] setObject:newDefaults forKey:CLDefaultPreferenceKey];
    
    [self.timezoneTableView reloadData];
    
    [self refreshMainTableview];
}

- (IBAction)filterArray:(id)sender
{
    [self clearLabel];
    
    self.filteredArray = [NSMutableArray array];
    
    if (self.searchField.stringValue.length > 50)
    {
        self.activityInProgress = NO;
        self.messageLabel.stringValue = CLMaxCharactersReachedError;
        [NSTimer scheduledTimerWithTimeInterval:10
                                         target:self
                                       selector:@selector(clearLabel)
                                       userInfo:nil
                                        repeats:NO];
        return;
    }
    
    if (self.searchField.stringValue.length > 0)
    {
        [self callGoogleAPiWithSearchString:self.searchField.stringValue];
    }
    else
    {
        if (self.dataTask.state == NSURLSessionTaskStateRunning) {
            [self.dataTask cancel];
        }
        self.activityInProgress = NO;
        self.placeholderLabel.placeholderString = CLEmptyString;
    }
        
    [self.availableTimezoneTableView reloadData];
}

- (void)refereshTimezoneTableView
{
     dispatch_async(dispatch_get_main_queue(), ^{
         
      NSMutableArray *defaultTimeZones = [[NSUserDefaults standardUserDefaults]
                                        objectForKey:CLDefaultPreferenceKey];
         
      self.selectedTimeZones = [[NSMutableArray alloc] initWithArray:defaultTimeZones];
         
      [self.timezoneTableView reloadData];
    });
}

- (void)refreshMainTableview
{
    dispatch_async(dispatch_get_main_queue(), ^{
        ApplicationDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        
        PanelController *panelController = appDelegate.panelController;
        
        [panelController updateDefaultPreferences];
        
        [panelController.mainTableview reloadData];
        
    });
}

#pragma mark Reordering

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    
    [pboard declareTypes:[NSArray arrayWithObject:CLDragSessionKey] owner:self];
    
    [pboard setData:data forType:CLDragSessionKey];
    
    return YES;
}


-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
    if (row == self.selectedTimeZones.count) {
        row--;
    }
    
    NSPasteboard *pBoard = [info draggingPasteboard];
    
    NSData *data = [pBoard dataForType:CLDragSessionKey];
    
    NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    [self.selectedTimeZones exchangeObjectAtIndex:rowIndexes.firstIndex withObjectAtIndex:row];
    
    [[NSUserDefaults standardUserDefaults] setObject:self.selectedTimeZones forKey:CLDefaultPreferenceKey];
    
    [self.timezoneTableView reloadData];
    
    [self refreshMainTableview];
    
    return YES;
}

-(NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    return NSDragOperationEvery;
}

- (void)callGoogleAPiWithSearchString:(NSString *)searchString
{
    if (self.dataTask.state == NSURLSessionTaskStateRunning) {
        [self.dataTask cancel];
    }
    
    if (self.availableTimezoneTableView.isHidden)
    {
        self.availableTimezoneTableView.hidden = NO;
    }
    
    self.placeholderLabel.hidden = NO;
    
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [reachability currentReachabilityStatus];
    
    if (networkStatus == NotReachable)
    {
        self.placeholderLabel.placeholderString = CLNoInternetConnectivityError;
        return;
    }
    
    self.activityInProgress = YES;

    self.placeholderLabel.placeholderString = [NSString stringWithFormat:@"Searching for '%@'", searchString];
    
    NSArray* words = [searchString componentsSeparatedByCharactersInSet :[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    searchString = [words componentsJoinedByString:CLEmptyString];
    
    NSString *urlString = [NSString stringWithFormat:CLLocationSearchURL, searchString];
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    request.HTTPMethod = @"GET";
    
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSError *error = nil;
    
    if (!error) {
        
        self.dataTask= [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error) {
                NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
        
                if (httpResp.statusCode == 200) {
                    
                     dispatch_async(dispatch_get_main_queue(), ^{

                      self.placeholderLabel.placeholderString = CLEmptyString;
                         
                         NSDictionary* json = [NSJSONSerialization
                                               JSONObjectWithData:data
                                               options:kNilOptions
                                               error:nil];
                         if ([json[@"status"] isEqualToString:@"ZERO_RESULTS"]) {
                             self.placeholderLabel.placeholderString = @"No results! 😔 Try entering the exact name.";
                             self.activityInProgress = NO;
                             return;
                         }
                         
                         for (NSDictionary *dictionary in json[@"results"])
                         {
                             NSDictionary *latLang = [[dictionary objectForKey:@"geometry"] objectForKey:@"location"];
                             NSString *latitude = latLang[@"lat"];
                             NSString *longitude = latLang[@"lng"];
                             NSString *formattedAddress = [dictionary objectForKey:@"formatted_address"];
                             
                             NSDictionary *totalPackage = @{@"latitude":latitude,
                                                            @"longitude" : longitude,
                                                            CLTimezoneName:formattedAddress,
                                                            CLCustomLabel: CLEmptyString,
                                                            CLTimezoneID : CLEmptyString,
                                                            CLPlaceIdentifier : dictionary[CLPlaceIdentifier]};
                             [self.filteredArray addObject:totalPackage];
                             
                         }
                         self.activityInProgress = NO;

                         [self.availableTimezoneTableView reloadData];

                     });
                  
                    }
                else
                {
                     dispatch_async(dispatch_get_main_queue(), ^{
                         self.placeholderLabel.placeholderString = [error.localizedDescription isEqualToString:@"The Internet connection appears to be offline."] ?
                         CLNoInternetConnectivityError : CLTryAgainMessage;
                         self.activityInProgress = NO;
                     });
               
                }
            }
            
        }];
        [self.dataTask resume];
        
    }
}

- (void)getTimeZoneForLatitude:(NSString *)latitude andLongitude:(NSString *)longitude
{
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [reachability currentReachabilityStatus];
    
    if (networkStatus == NotReachable)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
        self.placeholderLabel.placeholderString = CLNoInternetConnectivityError;
        self.activityInProgress = NO;
        self.filteredArray = [NSMutableArray array];
        [self.availableTimezoneTableView reloadData];
        });
        
        return;
    }
    
    self.searchField.placeholderString = @"Fetching data might take some time!";

    self.placeholderLabel.placeholderString = @"Retrieving timezone data";
  
    self.availableTimezoneTableView.hidden = YES;
    
    NSString *urlString = [NSString stringWithFormat:@"http://api.geonames.org/timezoneJSON?lat=%@&lng=%@&username=abhishaker17", latitude, longitude];
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    request.HTTPMethod = @"GET";
    
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];

    NSError *error = nil;
    
    if (!error) {
        
        self.dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error) {
                NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
                if (httpResp.statusCode == 200) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        NSDictionary* json = [NSJSONSerialization
                                              JSONObjectWithData:data
                                              options:kNilOptions
                                              error:nil];
                        
                        
                        if (json.count == 0) {
                            self.activityInProgress = NO;
                            self.placeholderLabel.placeholderString = @"No results found! ! 😔 Try Again?";
                            return;
                        }
                        
                        if ([json[@"status"][@"message"] isEqualToString:@"the hourly limit of 2000 credits for abhishaker17 has been exceeded. Please throttle your requests or use the commercial service."])
                        {
                            self.activityInProgress = NO;
                            self.placeholderLabel.placeholderString = @"API limit reached. Try again in an hour.?";
                            self.searchField.placeholderString = @"We rely on free APIs which have limits.";
                            return;
                        }
                        
                        
                        NSString *filteredAddress = [self.filteredArray[self.availableTimezoneTableView.selectedRow] objectForKey:CLTimezoneName];
                        NSRange range = [filteredAddress rangeOfString:@","];
                        if (range.location != NSNotFound)
                        {
                            filteredAddress = [[self.filteredArray[self.availableTimezoneTableView.selectedRow] objectForKey:CLTimezoneName ] substringWithRange:NSMakeRange(0, range.location)];
                        }
                        
                        NSMutableDictionary *newTimezone = [NSMutableDictionary dictionary];
                        if (json[@"sunrise"]) {
                               [newTimezone setObject:json[@"sunrise"] forKey:@"sunriseTime"];
                        }
                        if (json[@"sunset"]) {
                             [newTimezone setObject:json[@"sunset"] forKey:@"sunsetTime"];
                        }
                        
                        [newTimezone setObject:json[@"timezoneId"] forKey:CLTimezoneID];
                     
                        
                        [newTimezone setObject:filteredAddress forKey:CLTimezoneName];
                        [newTimezone setObject:self.filteredArray[self.availableTimezoneTableView.selectedRow][CLPlaceIdentifier] forKey:CLPlaceIdentifier];
                        [newTimezone setObject:latitude forKey:@"latitude"];
                        [newTimezone setObject:longitude forKey:@"longitude"];
                        [newTimezone setObject:CLEmptyString forKey:@"nextUpdate"];
                        [newTimezone setObject:CLEmptyString forKey:CLCustomLabel];
                        
                        NSArray *defaultPreference = [[NSUserDefaults standardUserDefaults] objectForKey:CLDefaultPreferenceKey];
                        
                        if (defaultPreference == nil)
                        {
                            defaultPreference = [[NSMutableArray alloc] init];
                        }
                        
                        NSMutableArray *newArray = [[NSMutableArray alloc] initWithArray:defaultPreference];
                        [newArray addObject:newTimezone];
                        
                        [[NSUserDefaults standardUserDefaults] setObject:newArray forKey:CLDefaultPreferenceKey];
                        
                        self.filteredArray = [NSMutableArray array];
                        
                        [self.availableTimezoneTableView reloadData];

                        [self refereshTimezoneTableView];
                        
                        [self refreshMainTableview];
                        
                        [self.timezonePanel close];
                        
                        self.placeholderLabel.placeholderString = CLEmptyString;
                        
                        self.searchField.placeholderString = @"Enter a city, state or country name";
                        
                        self.availableTimezoneTableView.hidden = NO;
                        
                        self.activityInProgress = NO;
                        
                    });
                }
            }
            else
            {
                self.placeholderLabel.placeholderString = [error.localizedDescription isEqualToString:@"The Internet connection appears to be offline."] ?
                CLNoInternetConnectivityError : CLTryAgainMessage;
                
                self.activityInProgress = NO;
            }
            
        }];
        
        [self.dataTask resume];
        
    }
}

@end