//
//  CIColor_ColorName.h
//  CLIArguments
//
//  Created by Eric McConville on 6/13/15.
//  Copyright (c) 2015 Eric McConville. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

@interface CIColor (X11ColorName)
+(CIColor *)colorWithName:(NSString *)colorname;
@end
