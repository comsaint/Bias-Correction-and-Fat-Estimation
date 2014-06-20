//
//  ITKtestFilter.h
//  ITKtest
//
//  Copyright (c) 2014 Long. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OsiriXAPI/PluginFilter.h>

//#import "MainNibWindowController.h"

@interface ITKtestFilter : PluginFilter {

}

- (ViewerController*) viewerController;
- (long) filterImage:(NSString*) menuName;

- (void) biascorrect:(ITKtestFilter*)filter;

@end
