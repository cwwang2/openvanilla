//
// OVSnippet_AppDelegate.m
//  
// Copyright (c) 2004-2007 The OpenVanilla Project (http://openvanilla.org)
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
// 3. Neither the name of OpenVanilla nor the names of its contributors
//    may be used to endorse or promote products derived from this software
//    without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#import "OVSnippet_AppDelegate.h"
#define MSG(x)      [[NSBundle mainBundle] localizedStringForKey:x value:nil table:nil]

@protocol CVDisplayServerPart
- (void)sendStringToCurrentComposingBuffer:(NSString *)string;
- (void)sendCharacterToCurrentComposingBuffer:(NSString *)string;
@end

NSPoint setWindowPosition(NSRect windowRect)
{	
	NSPoint point;
	NSRect frame = [[NSScreen mainScreen] frame];
	point.y = windowRect.size.height + 50;
	point.x = frame.size.width - windowRect.size.width - 20;		
	return point;
}

@implementation OVSnippet_AppDelegate

- (NSString *)applicationSupportFolder {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"OpenVanilla"];
}

- (NSManagedObjectModel *)managedObjectModel {

    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
	
    NSMutableSet *allBundles = [[NSMutableSet alloc] init];
    [allBundles addObject: [NSBundle mainBundle]];
    [allBundles addObjectsFromArray: [NSBundle allFrameworks]];
    
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles: [allBundles allObjects]] retain];
    [allBundles release];
    
    return managedObjectModel;
}

- (NSPersistentStoreCoordinator *) persistentStoreCoordinator {

    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }

    NSFileManager *fileManager;
    NSString *applicationSupportFolder = nil;
    NSURL *url;
    NSError *error;
    
    fileManager = [NSFileManager defaultManager];
    applicationSupportFolder = [self applicationSupportFolder];
    if ( ![fileManager fileExistsAtPath:applicationSupportFolder isDirectory:NULL] ) {
        [fileManager createDirectoryAtPath:applicationSupportFolder attributes:nil];
    }
    
    url = [NSURL fileURLWithPath: [applicationSupportFolder stringByAppendingPathComponent: @"OVSnippet.xml"]];
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:nil error:&error]){
        [[NSApplication sharedApplication] presentError:error];
    }    

    return persistentStoreCoordinator;
}
 
- (NSManagedObjectContext *) managedObjectContext {

    if (managedObjectContext != nil) {
        return managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    
    return managedObjectContext;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return [[self managedObjectContext] undoManager];
}
 
- (IBAction) saveAction:(id)sender {

    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}
 
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {

    NSError *error;
    int reply = NSTerminateNow;
    
    if (managedObjectContext != nil) {
        if ([managedObjectContext commitEditing]) {
            if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {				

                BOOL errorResult = [[NSApplication sharedApplication] presentError:error];
				
                if (errorResult == YES) {
                    reply = NSTerminateCancel;
                } 
            }
        } 
        else {
            reply = NSTerminateCancel;
        }
    }    
    return reply;
}

- (void) dealloc {
    [managedObjectContext release], managedObjectContext = nil;
    [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
    [managedObjectModel release], managedObjectModel = nil;
    [super dealloc];
}

- (void)windowWillClose:(NSNotification *)notification
{
	NSLog(@"OpenVanilla Snippets terminated.");
	[[NSApplication sharedApplication] terminate:self];	
}

- (void) insertSnippet:(NSString *)string {
	NSLog(@"Add object");
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSManagedObject *stringObject = [NSEntityDescription insertNewObjectForEntityForName:@"Snippet" inManagedObjectContext:moc];
	[stringObject setValue:string forKey:@"snippetItem"];
	NSLog(@"Done");	
}

// Services
// User should add new Snippet by using the Service Menu.

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setServicesProvider:self];
}

- (void)insertSnippetViaService:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error {
	
    NSString *pboardString;
    NSArray *types;
	
    types = [pboard types];	
    if (![types containsObject:NSStringPboardType] || !(pboardString = [pboard stringForType:NSStringPboardType])) {
        *error = NSLocalizedString(@"Error: Pasteboard doesn't contain a string.", @"Pasteboard couldn't give string.");
        return;
    }
	
	[self insertSnippet:pboardString];	
	[window orderFront:self]; 
    return;
}

/*
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op {
    // [tv setDropRow:[tv numberOfRows] dropOperation:NSTableViewDropAbove];
    return NSTableViewDropAbove;
}*/

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op
{
   NSLog(@"acceptDrop");
   NSPasteboard *myPasteboard=[info draggingPasteboard];
   NSString *string;	
   string=[myPasteboard stringForType:NSStringPboardType];
   [self insertSnippet:string];
   return YES;
}

- (void)awakeFromNib
{
   NSLog(@"Start!");
   _displayServer = [[NSConnection rootProxyForConnectionWithRegisteredName:@"OVNewDisplayServer-0.8.0" host:nil] retain];

   if (_displayServer) {
      [_displayServer setProtocolForProxy:@protocol(CVDisplayServerPart)];		
      [window setLevel:NSFloatingWindowLevel];
   }
   else {
      NSLog(@"cannot find display server");
      [[NSApplication sharedApplication] terminate:self];	
   }

   [window setFrameTopLeftPoint:setWindowPosition([window frame])];
   // Make it posssible to drag and drop text into snippetListview
   [snippetListview registerForDraggedTypes:
      [NSArray arrayWithObjects:NSStringPboardType,nil]];	
   [snippetListview setDelegate:self];
   [snippetListview setDoubleAction:@selector(tableAction)];
   [snippetListview setDraggingSourceOperationMask:NSDragOperationLink
      forLocal:NO];
   [snippetListview setDraggingSourceOperationMask:NSDragOperationCopy
      forLocal:YES];	

}


- (void)tableAction {
   [_displayServer sendStringToCurrentComposingBuffer:[sendKey toolTip]];
}

- (IBAction)stringAction:(id)sender
{
   [_displayServer sendStringToCurrentComposingBuffer:[sender toolTip]];
}

@end
