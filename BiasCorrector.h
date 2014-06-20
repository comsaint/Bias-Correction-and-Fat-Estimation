//
//  BiasCorrector.h
//  ITKtest
//
//  Created by Long Pun on 19/06/14.
//
//

#import <Cocoa/Cocoa.h>
//#import "ITKtestFilter.h"

@class ITKtestFilter;

@interface BiasCorrector : NSObject{

}

-(void) biascorrect:(ITKtestFilter*) filter;

@end
