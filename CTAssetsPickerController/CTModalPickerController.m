
/*
 CTModalPickerController.m
 
 The MIT License (MIT)
 
 Copyright (c) 2013 Clement CN Tsang
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 
 */
 

#import "CTAssetsPickerController.h"
#import "CTAssetsPageViewController.h"
#import "CTModalPickerController.h"


@interface CTModalPickerController ()
<CTAssetsPickerControllerDelegate, UIPopoverControllerDelegate>

@property (nonatomic, copy) NSArray *assets;
@property (nonatomic, strong) ALAsset* removeAssetOnViewDidAppear;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) UIPopoverController *popover;

@end



@implementation CTModalPickerController

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.removeAssetOnViewDidAppear = nil;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.allowsMultipleSelectionDuringEditing = NO;
    
    UIBarButtonItem *clearButton =
    [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", nil)
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(cancel:)];
    
    
    UIBarButtonItem *addButton =
    [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Send", nil)
                                     style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(send:)];
    
    self.navigationItem.leftBarButtonItem = clearButton;
    self.navigationItem.rightBarButtonItem = addButton;
    
    self.dateFormatter = [[NSDateFormatter alloc] init];
    self.dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    self.dateFormatter.timeStyle = NSDateFormatterMediumStyle;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)cancel:(id)sender
{
    if ([self delegate])
        [[self delegate] modalPickerController:self didCancelWithAssets:self.assets];
}

- (void)send:(id)sender
{
    if ([self delegate])
        [[self delegate] modalPickerController:self didCompleteWithAssets:self.assets];
}

- (void)pickAssets:(id)sender animated:(BOOL)animated
{
    if (!self.assets)
        self.assets = [[NSMutableArray alloc] init];
    
    CTAssetsPickerController *picker = [[CTAssetsPickerController alloc] init];
    picker.assetsFilter         = [ALAssetsFilter allAssets];
    picker.showsCancelButton    = (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad);
    picker.delegate             = self;
    picker.selectedAssets       = [NSMutableArray arrayWithArray:self.assets];
    
    // iPad
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        self.popover = [[UIPopoverController alloc] initWithContentViewController:picker];
        self.popover.delegate = self;
        
        [self.popover presentPopoverFromBarButtonItem:sender
                             permittedArrowDirections:UIPopoverArrowDirectionAny
                                             animated:YES];
    }
    else
    {
        [self presentViewController:picker animated:animated completion:nil];
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.assets.count + 1;
}

- (void)viewWillAppear:(BOOL)animated
{
    [[self tableView] reloadData];
    [self updateSendCount];
    [self updatePlaceholder];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell;
    
    if (indexPath.row == self.assets.count)
    {
        cell = [tableView dequeueReusableCellWithIdentifier:@"PlaceholderCell"];
        
        if (!cell)
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"PlaceholderCell"];
        
        [[cell textLabel] setTextColor:[[UIApplication sharedApplication] keyWindow].tintColor];
        [[cell textLabel] setTextAlignment:NSTextAlignmentCenter];
        return cell;
    }
    
    cell = [tableView dequeueReusableCellWithIdentifier:@"SelectedImageCell"];
    
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"SelectedImageCell"];
    
    ALAsset *asset = [self.assets objectAtIndex:indexPath.row];
    
    if ([asset valueForProperty:ALAssetPropertyType] == ALAssetTypePhoto)
        cell.textLabel.text = @"Photo";
    else if ([asset valueForProperty:ALAssetPropertyType] == ALAssetTypeVideo)
        cell.textLabel.text = @"Video";
    else if ([asset valueForProperty:ALAssetPropertyType] == ALAssetTypeUnknown)
        cell.textLabel.text = @"Unknown";
    
    cell.textLabel.text = [NSString stringWithFormat:@"%@ #%li", cell.textLabel.text, indexPath.row + 1];
    
    cell.detailTextLabel.text = [self.dateFormatter stringFromDate:[asset valueForProperty:ALAssetPropertyDate]];
    cell.imageView.image = [UIImage imageWithCGImage:asset.thumbnail];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == self.assets.count)
    {
        [self pickAssets:self animated:YES];
        return;
    }
    
    CTAssetsPageViewController *vc = [[CTAssetsPageViewController alloc] initWithAssets:self.assets];
    vc.pageIndex = indexPath.row;
    vc.pageViewDelegate = self;
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == [self.assets count])
        return NO;
    return YES;
}

- (void)updateSendCount
{
    if ([self.assets count] > 0)
    {
        [self.navigationItem.rightBarButtonItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Send (%i)", nil), [self.assets count]]];
        [self.navigationItem.rightBarButtonItem setEnabled:YES];
    } else
    {
        [self.navigationItem.rightBarButtonItem setTitle:@"Send"];
        [self.navigationItem.rightBarButtonItem setEnabled:NO];
    }
}

- (void)updatePlaceholder
{
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[[self assets] count] inSection:0];
    UITableViewCell* placeholderCell = [[self tableView] cellForRowAtIndexPath:indexPath];
    
    if (self.assets.count > 0)
        [[placeholderCell textLabel] setText:@"Change selection"];
    else
        [[placeholderCell textLabel] setText:@"Add photo or video"];
}

- (void)updateImageCellsCounter
{
    NSArray* visibleRows = [[self tableView] indexPathsForVisibleRows];
    for (NSIndexPath* indexPath in visibleRows)
    {
        if (indexPath.row == [self.assets count])
            continue;
        
        UITableViewCell* cell = [[self tableView] cellForRowAtIndexPath:indexPath];
        ALAsset *asset = [self.assets objectAtIndex:indexPath.row];
        
        if ([asset valueForProperty:ALAssetPropertyType] == ALAssetTypePhoto)
            cell.textLabel.text = @"Photo";
        else if ([asset valueForProperty:ALAssetPropertyType] == ALAssetTypeVideo)
            cell.textLabel.text = @"Video";
        else if ([asset valueForProperty:ALAssetPropertyType] == ALAssetTypeUnknown)
            cell.textLabel.text = @"Unknown";
        
        cell.textLabel.text = [NSString stringWithFormat:@"%@ #%li", cell.textLabel.text, indexPath.row + 1];
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        ALAsset* asset = [self.assets objectAtIndex:indexPath.row];
        [self removeAsset:asset];
    }
}

- (void)selectAsset:(ALAsset*)asset
{
    [self addAsset:asset];
}

- (void)unselectAsset:(ALAsset*)asset
{
    _removeAssetOnViewDidAppear = asset;
    [[self navigationController] popViewControllerAnimated:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (_removeAssetOnViewDidAppear != nil)
    {
        [self removeAsset:_removeAssetOnViewDidAppear];
        _removeAssetOnViewDidAppear = nil;
    }
}

- (void)addAsset:(ALAsset*)asset
{
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[self.assets count] inSection:0];
    NSMutableArray* copy = [self.assets mutableCopy];
    [copy insertObject:asset atIndex:indexPath.row];
    self.assets = copy;
    [[self tableView] insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self updateSendCount];
    [self updatePlaceholder];
}

- (void)removeAsset:(ALAsset*)asset
{
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[self.assets indexOfObject:asset] inSection:0];
    NSMutableArray* copy = [self.assets mutableCopy];
    [copy removeObject:asset];
    self.assets = copy;
    [[self tableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    [self updateSendCount];
    [self updatePlaceholder];
    [self updateImageCellsCounter];
}

- (BOOL)isSelected:(ALAsset*)asset
{
    return [[self assets] indexOfObject:asset] != NSNotFound;
}


#pragma mark - Popover Controller Delegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.popover = nil;
}


#pragma mark - Assets Picker Delegate

- (BOOL)assetsPickerController:(CTAssetsPickerController *)picker isDefaultAssetsGroup:(ALAssetsGroup *)group
{
    return ([[group valueForProperty:ALAssetsGroupPropertyType] integerValue] == ALAssetsGroupSavedPhotos);
}

- (void)assetsPickerController:(CTAssetsPickerController *)picker didFinishPickingAssets:(NSArray *)assets
{
    if (self.popover != nil)
        [self.popover dismissPopoverAnimated:YES];
    else
        [picker.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    
    self.assets = [NSMutableArray arrayWithArray:assets];
    [self.tableView reloadData];
    [self updateSendCount];
    [self updatePlaceholder];
}

- (BOOL)assetsPickerController:(CTAssetsPickerController *)picker shouldEnableAsset:(ALAsset *)asset
{
    return YES;
}

- (BOOL)assetsPickerController:(CTAssetsPickerController *)picker shouldSelectAsset:(ALAsset *)asset
{
    if ([[asset valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypeVideo])
    {
        NSTimeInterval duration = [[asset valueForProperty:ALAssetPropertyDuration] doubleValue];
        if (lround(duration) > 10)
        {
            UIAlertView *alertView =
            [[UIAlertView alloc] initWithTitle:@"Video is too long"
                                       message:@"Videos cannot exceed 10 seconds."
                                      delegate:nil
                             cancelButtonTitle:nil
                             otherButtonTitles:@"OK", nil];
            
            [alertView show];
            return NO;
        }
    }
    
    if (picker.selectedAssets.count >= 15)
    {
        UIAlertView *alertView =
        [[UIAlertView alloc] initWithTitle:@"Too many photos selected"
                                   message:@"Please select no more than 15 photos or videos."
                                  delegate:nil
                         cancelButtonTitle:nil
                         otherButtonTitles:@"OK", nil];
        
        [alertView show];
        return NO;
    }
    
    if (!asset.defaultRepresentation)
    {
        UIAlertView *alertView =
        [[UIAlertView alloc] initWithTitle:@"Unable to send this media"
                                   message:@"This media has not yet been downloaded to your device."
                                  delegate:nil
                         cancelButtonTitle:nil
                         otherButtonTitles:@"OK", nil];
        [alertView show];
        return NO;
    }
    
    return YES;
}

@end
