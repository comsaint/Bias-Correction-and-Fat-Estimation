//
//  MainNibWindowController.h
//  ITKtest
//
//  Created by Long Pun on 19/06/14.
//
//

#import <AppKit/AppKit.h>

@class ITKtestFilter;

@class ROI;
@class ViewerController;
@class DCMPix;

@interface MainNibWindowController : NSWindowController
{
    NSButton *compute_BC;
    IBOutlet NSTextFieldCell *ratingOut;
    
    
    ITKtestFilter* filter;
    
    DCMPix *pix;
    ROI *curROI;
}

- (id) init: (ITKtestFilter*) f;

- (IBAction)update:(id)sender;
- (IBAction)BC_button:(id)sender;
- (IBAction)calculateRating_Button:(id)sender;

@end
