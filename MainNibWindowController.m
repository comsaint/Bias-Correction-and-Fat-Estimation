//
//  MainNibWindowController.m
//  ITKtest
//
//  Created by Long Pun on 19/06/14.
//
//

#import "MainNibWindowController.h"

#import "ITKtestFilter.h"


@class ROI;
@class ViewerController;
@class DCMPix;

@interface MainNibWindowController ()

@end

@implementation MainNibWindowController


- (id) init: (ITKtestFilter*) f
{
    return 0;
}


- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)awakeFromNib
{
	NSLog( @"Nib loaded!");
	
	NSNotificationCenter *nc;
    nc = [NSNotificationCenter defaultCenter];
    [nc addObserver: self
           selector: @selector(closeViewer:)
               name: @"CloseViewerNotification"
             object: nil];
	
	[nc addObserver: self
           selector: @selector(roiChange:)
               name: @"roiChange"
             object: nil];
	
	[nc addObserver: self
           selector: @selector(roiChange:)
               name: @"removeROI"
             object: nil];
	
	[nc addObserver: self
           selector: @selector(roiChange:)
               name: @"roiSelected"
             object: nil];
}



- (IBAction)update:(id)sender
{
    [self init:filter];
}

- (void) closeViewer :(NSNotification*) note
{
	if( [note object] == [filter viewerController])
	{
		[[NSNotificationCenter defaultCenter] removeObserver: self];
		[self autorelease];
	}
}

- (void)windowWillClose:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[self autorelease];
}

- (void) dealloc
{
    /*
	[curROI release];
	curROI = 0L;
    */
    
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[super dealloc];
}@end
