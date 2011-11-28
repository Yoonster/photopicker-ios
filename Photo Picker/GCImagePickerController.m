/*
 
 Copyright (C) 2011 GUI Cocoa, LLC.
 
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

#import <MobileCoreServices/MobileCoreServices.h>

#import "GCImagePickerController.h"
#import "GCIPViewController_Pad.h"
#import "GCIPGroupPickerController.h"

@interface GCImagePickerController ()
@property (nonatomic, readwrite, retain) ALAssetsLibrary *assetsLibrary;
- (void)reloadChildren;
@end

@implementation GCImagePickerController

#pragma mark - class methods

+ (NSString *)localizedString:(NSString *)key {
    return [[NSBundle mainBundle] localizedStringForKey:key value:nil table:NSStringFromClass(self)];
}
+ (void)failedToLoadAssetsWithError:(NSError *)error {
    NSLog(@"%@", error);
    NSInteger code = [error code];
    if (code == ALAssetsLibraryAccessUserDeniedError || code == ALAssetsLibraryAccessGloballyDeniedError) {
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle:[self localizedString:@"ERROR"]
                              message:[self localizedString:@"PHOTO_ROLL_LOCATION_ERROR"]
                              delegate:nil
                              cancelButtonTitle:[self localizedString:@"OK"]
                              otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
    else {
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle:[self localizedString:@"ERROR"]
                              message:[self localizedString:@"UNKNOWN_LIBRARY_ERROR"]
                              delegate:nil
                              cancelButtonTitle:[self localizedString:@"OK"]
                              otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}
+ (NSString *)extensionForAssetRepresentation:(ALAssetRepresentation *)rep {
    NSString *UTI = [rep UTI];
    if (UTI == nil) {
        NSLog(@"Missing UTI for asset representation %@", UTI);
        return nil;
    }
    else {
        return [GCImagePickerController extensionForUTI:(CFStringRef)UTI];
    }
}
+ (NSString *)MIMETypeForAssetRepresentation:(ALAssetRepresentation *)rep {
    NSString *UTI = [rep UTI];
    if (UTI == nil) {
        NSLog(@"Missing MIME type for asset representation %@", UTI);
        return nil;
    }
    else {
        return [GCImagePickerController MIMETypeForUTI:(CFStringRef)UTI];
    }
}
+ (NSString *)extensionForUTI:(CFStringRef)UTI {
    if (UTI == NULL) {
        NSLog(@"Requested extension for nil UTI");
        return nil;
    }
    else if (CFStringCompare(UTI, kUTTypeJPEG, 0) == kCFCompareEqualTo) {
        return @"jpg";
    }
    else {
        CFStringRef extension = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassFilenameExtension);
        if (extension == NULL) {
            NSLog(@"Missing extension for UTI %@", (NSString *)UTI);
            return nil;
        }
        else {
            return [(NSString *)extension autorelease];
        }
    }
}
+ (NSString *)MIMETypeForUTI:(CFStringRef)UTI {
    if (UTI == NULL) {
        NSLog(@"Requested MIME type for nil UTI");
        return nil;
    }
    else {
        CFStringRef MIME = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
        if (MIME == NULL) {
            NSLog(@"Missing MIME type for UTI %@", (NSString *)UTI);
            return nil;
        }
        else {
            return [(NSString *)MIME autorelease];
        }
    }
}
+ (NSData *)dataForAssetRepresentation:(ALAssetRepresentation *)rep {
    long long size = [rep size];
    long long offset = 0;
    NSMutableData *data = [[NSMutableData alloc] init];
    while (offset < size) {
        uint8_t bytes[1024];
        NSError *error = nil;
        NSUInteger written = [rep getBytes:bytes fromOffset:offset length:1024 error:&error];
        if (error) {
            NSLog(@"%@", error);
            [data release];
            data = nil;
            break;
        }
        [data appendBytes:bytes length:written];
        offset += written;
    }
    return [data autorelease];
}
+ (BOOL)writeDataForAssetRepresentation:(ALAssetRepresentation *)rep
                                 toFile:(NSString *)path
                             atomically:(BOOL)atomically {
    
    // return if the file exists already
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return NO;
    }
    
    // get write path
	NSString *writePath = path;
	if (atomically) {
		writePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[path lastPathComponent]];
	}
    
    // return if we cannot create a file handle
    if (![[NSFileManager defaultManager] createFileAtPath:writePath contents:nil attributes:nil]) {
        return NO;
    }
    
    // create file handle and return if unsuccessful
	NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:writePath];
    if (!handle) { return NO; }
    
    // do writing
	long long size = [rep size];
    long long offset = 0;
	while (offset < size) {
		uint8_t buffer[1024];
        NSError *error = nil;
        NSUInteger written = [rep getBytes:buffer fromOffset:offset length:1024 error:&error];
        if (error) {
            NSLog(@"%@", error);
            [handle closeFile];
            [[NSFileManager defaultManager] removeItemAtPath:writePath error:nil];
            return NO;
        }
        NSData *toWrite = [[NSData alloc] initWithBytes:buffer length:written];
        [handle writeData:toWrite];
        [toWrite release];
        offset += written;
	}
	[handle closeFile];
    
    // move file into place
	if (atomically) {
		if (![[NSFileManager defaultManager] moveItemAtPath:writePath toPath:path error:nil]) {
            [[NSFileManager defaultManager] removeItemAtPath:writePath error:nil];
            return NO;
        }
	}
    
    // it worked!
    return YES;
    
}
+ (NSArray *)assetsGroupsInLibary:(ALAssetsLibrary *)library
                        withTypes:(ALAssetsGroupType)types
                     assetsFilter:(ALAssetsFilter *)filter
                            error:(NSError **)inError {
    
    // check library
    if (library == nil) { return nil; }
    
    // load groups
    __block BOOL wait = YES;
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    NSMutableArray *groups = [NSMutableArray array];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [library
         enumerateGroupsWithTypes:types
         usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
             if (group) {
                 [group setAssetsFilter:filter];
                 if ([group numberOfAssets]) {
                     NSNumber *type = [group valueForProperty:ALAssetsGroupPropertyType];
                     NSMutableArray *array = [dictionary objectForKey:type];
                     if (array == nil) {
                         array = [NSMutableArray arrayWithCapacity:1];
                         [dictionary setObject:array forKey:type];
                     }
                     [array addObject:group];
                 }
             }
             else {
                 
                 // sort known groups into final container
                 NSArray *typeNumbers = [NSArray arrayWithObjects:
                                         [NSNumber numberWithUnsignedInteger:ALAssetsGroupSavedPhotos],
                                         [NSNumber numberWithUnsignedInteger:ALAssetsGroupPhotoStream],
                                         [NSNumber numberWithUnsignedInteger:ALAssetsGroupLibrary],
                                         [NSNumber numberWithUnsignedInteger:ALAssetsGroupAlbum],
                                         [NSNumber numberWithUnsignedInteger:ALAssetsGroupEvent],
                                         [NSNumber numberWithUnsignedInteger:ALAssetsGroupFaces],
                                         nil];
                 for (NSNumber *type in typeNumbers) {
                     NSArray *groupsByType = [dictionary objectForKey:type];
                     [groups addObjectsFromArray:groupsByType];
                     [dictionary removeObjectForKey:type];
                 }
                 
                 // get any groups we do not have contants for
                 for (NSNumber *type in [dictionary keysSortedByValueUsingSelector:@selector(compare:)]) {
                     NSArray *groupsByType = [dictionary objectForKey:type];
                     [groups addObjectsFromArray:groupsByType];
                     [dictionary removeObjectForKey:type];
                 }
                 
                 // unlock
                 wait = NO;
                 
             }
         }
         failureBlock:^(NSError *error) {
             if (inError) { *inError = [error retain]; }
             wait = NO;
         }];
    });
    
    // spin
    if ([library respondsToSelector:@selector(addAssetsGroupAlbumWithName:resultBlock:failureBlock:)]) {
        while (wait) {
            [NSThread sleepForTimeInterval:0.1];
        }
    }
    else {
        while (wait) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
    }
    
    
    // wait
    if (inError) { [*inError autorelease]; }
    return groups;
    
}
+ (NSArray *)assetsInLibary:(ALAssetsLibrary *)library 
        groupWithIdentifier:(NSString *)identifier
                     filter:(ALAssetsFilter *)filter
                      group:(ALAssetsGroup **)inGroup
                      error:(NSError **)inError {
    
    // check library
    if (library == nil) { return nil; }
    
    // load assets
    __block BOOL wait = YES;
    NSMutableArray *assets = [NSMutableArray array];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [library
         enumerateGroupsWithTypes:ALAssetsGroupAll
         usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
             if (group) {
                 NSString *groupID = [group valueForProperty:ALAssetsGroupPropertyPersistentID];
                 if ([groupID isEqualToString:identifier]) {
                     [group setAssetsFilter:filter];
#if 0
                     [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                         if (result) { [assets addObject:result]; }
                     }];
#else
                     [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                         if (result) { [assets addObject:result]; }
                     }];
#endif
                     if (inGroup) { *inGroup = [group retain]; }
                     *stop = YES;
                     wait = NO;
                 }
             }
             else {
                 wait = NO;
             }
         }
         failureBlock:^(NSError *error) {
             if (inError) { *inError = [error retain]; }
             wait = NO;
         }];
    });
    
    
    // wait
    if ([library respondsToSelector:@selector(addAssetsGroupAlbumWithName:resultBlock:failureBlock:)]) {
        while (wait) {
            [NSThread sleepForTimeInterval:0.1];
        }
    }
    else {
        while (wait) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }
    }
    
    // return
    if (inGroup) { [*inGroup autorelease]; }
    if (inError) { [*inError autorelease]; }
    return assets;
    
}

#pragma mark - object methods

@synthesize assetsLibrary   = __assetsLibrary;
@synthesize actionBlock     = __actionBlock;
@synthesize actionTitle     = __actionTitle;
@synthesize assetsFilter    = __assetsFilter;

- (id)initWithRootViewController:(UIViewController *)root {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        GCIPViewController_Pad *controller = [[GCIPViewController_Pad alloc] initWithNibName:nil bundle:nil];
        self = [super initWithRootViewController:controller];
        controller.parent = self;
        [controller release];
    }
    else {
        GCIPGroupPickerController *controller = [[GCIPGroupPickerController alloc] initWithNibName:nil bundle:nil];
        self = [super initWithRootViewController:controller];
        controller.parent = self;
        [controller release];
    }
    if (self) {
        self.modalPresentationStyle = UIModalPresentationPageSheet;
        self.assetsLibrary = [[[ALAssetsLibrary alloc] init] autorelease];
        [self.assetsLibrary writeImageToSavedPhotosAlbum:nil metadata:nil completionBlock:nil];
        self.assetsFilter = [ALAssetsFilter allAssets];
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(assetsLibraryDidChange:)
         name:ALAssetsLibraryChangedNotification
         object:self.assetsLibrary];
    }
    return self;
}
- (void)dealloc {
    
    // clear notifs
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:ALAssetsLibraryChangedNotification
     object:self.assetsLibrary];
    
    // clear properties
    self.assetsLibrary = nil;
    self.actionBlock = nil;
    self.actionTitle = nil;
    self.assetsFilter = nil;
    
    // super
    [super dealloc];
    
}
- (void)reloadChildren {
    [self.viewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[GCIPViewController class]]) {
            [(GCIPViewController *)obj reloadAssets];
        }
    }];
}
- (void)assetsLibraryDidChange:(NSNotification *)notif {
    [self reloadChildren];
}

@end
