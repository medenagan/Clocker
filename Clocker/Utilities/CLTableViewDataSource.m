//
//  CLTableViewDataSource.m
//  Clocker
//
//  Created by Abhishek Banthia on 7/25/16.
//
//

#import "CLTableViewDataSource.h"
#import "CLTimezoneCellView.h"
#import "CLTimezoneData.h"
#import "CLTimezoneDataOperations.h"
#import "CommonStrings.h"
#import "CLOneWindowController.h"

NSString *const CLTimezoneCellViewID = @"timeZoneCell";

@interface CLTableViewDataSource()


@end

@implementation CLTableViewDataSource

-(instancetype)initWithItems:(NSMutableArray *)objects
{
    self = [super init];
    
    if (self) {
        self.timezoneObjects = objects;
    }
    
    return self;
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.timezoneObjects.count;
}
-(NSView*)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    CLTimezoneCellView *cell = [tableView makeViewWithIdentifier:CLTimezoneCellViewID owner:self];
    
    CLTimezoneData *dataObject = [CLTimezoneData getCustomObject:self.timezoneObjects[row]];
    
    CLTimezoneDataOperations *dataOperation = [[CLTimezoneDataOperations alloc] initWithTimezoneData:dataObject];
    
    cell.sunriseSetTime.stringValue = [dataOperation getFormattedSunriseOrSunsetTimeAndSliderValue:self.futureSliderValue];
    
    cell.relativeDate.stringValue = [dataOperation getDateForTimeZoneWithFutureSliderValue:self.futureSliderValue andDisplayType:CLPanelDisplay];
    
    cell.time.stringValue = [dataOperation getTimeForTimeZoneWithFutureSliderValue:self.futureSliderValue];
    
    cell.rowNumber = row;
    
    cell.customName.stringValue = [dataObject getFormattedTimezoneLabel];
    
    [self tableView:tableView setupCell:cell forRow:row];
    
    return cell;
}

- (void)tableView:(NSTableView *)tableView setupCell:(CLTimezoneCellView *)cell forRow:(NSInteger)row
{
    
    NSNumber *theme = [[NSUserDefaults standardUserDefaults] objectForKey:CLThemeKey];
    
    CLTimezoneData *dataObject = [CLTimezoneData getCustomObject:self.timezoneObjects[row]];
    
    NSTextView *customLabel = (NSTextView*)[cell.relativeDate.window
                                            fieldEditor:YES
                                            forObject:cell.relativeDate];
    
    if (theme.integerValue == 1)
    {
        tableView.backgroundColor = [NSColor blackColor];
        customLabel.insertionPointColor = [NSColor whiteColor];
        cell.sunriseSetImage.image = dataObject.sunriseOrSunset ?
        [NSImage imageNamed:@"WhiteSunrise"] : [NSImage imageNamed:@"WhiteSunset"];
    }
    else
    {
        
        tableView.backgroundColor = [NSColor whiteColor];
        customLabel.insertionPointColor = [NSColor blackColor];
        cell.sunriseSetImage.image = dataObject.sunriseOrSunset ?
        [NSImage imageNamed:@"Sunrise"] : [NSImage imageNamed:@"Sunset"];
    }
    
    NSNumber *displaySunriseSunsetTime = [[NSUserDefaults standardUserDefaults] objectForKey:CLSunriseSunsetTime];
    
    cell.sunriseSetTime.hidden = ([displaySunriseSunsetTime isEqualToNumber:@(0)] && cell.sunriseSetTime.stringValue.length > 0) ? NO : YES;
    
    cell.sunriseSetImage.hidden = [displaySunriseSunsetTime isEqualToNumber:@(0)] && cell.sunriseSetTime.stringValue.length > 0 ? NO : YES;
    
    [cell setUpLayout];

}



- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard declareTypes:@[CLDragSessionKey] owner:self];
    [pboard setData:data forType:CLDragSessionKey];
    return YES;
}

-(void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([object isKindOfClass:[NSString class]])
    {
        CLTimezoneData *dataObject = self.timezoneObjects[row];
        
        if ([dataObject.formattedAddress isEqualToString:object])
        {
            return;
        }
        
        [dataObject setLabelForTimezone:object];
        (self.timezoneObjects)[row] = dataObject;
        [[NSUserDefaults standardUserDefaults] setObject:self.timezoneObjects forKey:CLDefaultPreferenceKey];
        [tableView reloadData];
    }
}

-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation
{
    
    if (row == self.timezoneObjects.count)
    {
        row -= 1;
    }
    
    NSPasteboard *pBoard = [info draggingPasteboard];
    
    NSData *data = [pBoard dataForType:CLDragSessionKey];
    
    NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    [self.timezoneObjects exchangeObjectAtIndex:rowIndexes.firstIndex
                                 withObjectAtIndex:row];
    
    [[NSUserDefaults standardUserDefaults] setObject:self.timezoneObjects
                                              forKey:CLDefaultPreferenceKey];
    
    
    [[NSApplication sharedApplication].windows enumerateObjectsUsingBlock:^(NSWindow * _Nonnull window, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([window.windowController isMemberOfClass:[CLOneWindowController class]]) {
            CLOneWindowController *oneWindowController = (CLOneWindowController *) window.windowController;
            [oneWindowController.preferencesView refereshTimezoneTableView];
        }
        
    }];
    
    [tableView reloadData];
    
    return YES;
}

-(NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    return NSDragOperationEvery;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    NSNumber *userFontSize = [[NSUserDefaults standardUserDefaults] objectForKey:CLUserFontSizePreference];
    return 61 + userFontSize.integerValue;
}


@end
