//
//  ITKtestFilter.h
//  ITKtest
//
//  Copyright (c) 2014 Long. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OsiriXAPI/PluginFilter.h>
//#import <vector.h>

//#import "MainNibWindowController.h"
//typedef std::pair<float, float> mypair;

@interface ITKtestFilter : PluginFilter {
    DCMPix *pix;
    float pix_max,pix_min;//store the max and min values of a slice
    float skewness;
}

- (ViewerController*) viewerController;
- (long) filterImage:(NSString*) menuName;

- (void) biascorrect:(ITKtestFilter*)filter;
- (void) Setpix:(DCMPix*) pix_in;
//- (float) setSkewness;
- (float) getSkewness;
- (float) calculateRating:(ROI*)curROI;
//- (bool) comparator:(const mypair&) l :(const mypair&) r;
@end
