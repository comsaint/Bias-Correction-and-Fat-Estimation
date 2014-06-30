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

@implementation MainNibWindowController


- (id) init: (ITKtestFilter*) f
{
    self = [super initWithWindowNibName:@"MainNibWindowController"];
    
	//[[self window] setDelegate:self];   //In order to receive the windowWillClose notification!
    
    /*
     if(!self){
         NSRunInformationalAlertPanel(@"Hell", @"I don't know", @"Doh!", nil, nil);
     }
     else {
         NSRunInformationalAlertPanel(@"Yeah", @"I know", @"OK", nil, nil);
     };
     */
    
    [self showWindow:self];
    filter = f;
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

//
- (IBAction)update:(id)sender
{
    [self init:filter];
}

- (IBAction)BC_button:(id)sender
{
    [filter biascorrect:filter];
}

- (IBAction)calculateRating_Button:(id)sender
{
    //Get the roi
    NSMutableArray		*roiSeriesList = [[filter viewerController]roiList];
    int curslice = [[[filter viewerController] imageView]curImage];
    NSMutableArray *roiImageList = [roiSeriesList objectAtIndex :curslice];
    
    // Get the pixels
    NSArray *PixList = [[filter viewerController]pixList];
    pix = [PixList objectAtIndex:curslice];
    [filter Setpix:pix];
    
    for (int i=0; i<[roiImageList count];i++)
    {
        curROI = [roiImageList objectAtIndex: i];
        if( [curROI ROImode] == ROI_selected || [curROI ROImode] == ROI_selectedModify)
        {
            float rating = [filter calculateRating:curROI];
            [self->ratingOut setFloatValue:rating];
            [self->skewnessOut setFloatValue:[filter getSkewness]];
            break;
        }
    }
    
    [self showWindow:self];
    
    //return 0;
    
}
//
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
