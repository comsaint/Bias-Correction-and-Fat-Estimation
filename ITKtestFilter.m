//
//  ITKtestFilter.m
//  ITKtest
//
//  Copyright (c) 2014 Long. All rights reserved.
//

#import "ITKtestFilter.h"
#import "MainNibWindowController.h"

/*
#import "BiasCorrector.h"
#import "FatRatingCalculator.h"
*/

@implementation ITKtestFilter


- (void) initPlugin
{
}

- (ViewerController*) viewerController
{
    return viewerController;
}


- (long) filterImage:(NSString*) menuName
{
    MainNibWindowController* coWin = [[MainNibWindowController alloc] init:self];
    [coWin showWindow:self];
    
    return 0;
}

@end