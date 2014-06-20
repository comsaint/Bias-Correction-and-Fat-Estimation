//
//  MainNibWindowController.h
//  ITKtest
//
//  Created by Long Pun on 19/06/14.
//
//

#import <AppKit/AppKit.h>


@class ITKtestFilter;

@interface MainNibWindowController : NSWindowController
{
    NSButton *compute_BC;
    ITKtestFilter* filter;
}

- (id) init: (ITKtestFilter*) f;

- (IBAction)update:(id)sender;

- (IBAction)BC_button:(id)sender;

@end
