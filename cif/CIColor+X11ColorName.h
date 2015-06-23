//
//  CIColor_ColorName.h
//  CLIArguments
//
//  Created by Eric McConville on 6/13/15.
//  Copyright (c) 2015 Eric McConville. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <Cocoa/Cocoa.h>

@interface CIColor (X11ColorName)

/**
 * @brief Load CIColor from common X11 color name.
 * @param colorname A lowercase X11 colorname.
 * @return CIColor or nil on failure
 */
+(CIColor *)colorWithName:(NSString *)colorname;

/**
 * @brief Wrap NSColor's HSL method for CI scope.
 * @return CIColor or nil on failure
 */
+(CIColor *)colorWithHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness alpha:(CGFloat)alpha;

/**
 * @brief Conver hex-triplet strings to CIColor.
 * @discussion Supports shorthand `#FFF`, 8-bit `#FFFFFF` and 8-bit + alpha
 *             channel `#FFFFFFFF`.
 * @param hexTriplet Color repr
 * @return CIColor or nil on failure
 */
+(CIColor *)colorWithHexString:(NSString *)hexTriplet;

/**
 * @brief Convert rgb(#,#,#) to CIColor
 * @param colorname A lowercase rgb[a] color-function.
 * @return CIColor or nil on failure
 */
+(CIColor *)colorWithRgbString:(NSString *)rgbString;

/**
 * @brief Convert hsl(',%,%) to CIColor
 * @param colorname A lowercase hsl[a] color-function.
 * @return CIColor or nil on failure
 */
+(CIColor *)colorWithHslString:(NSString *)hslString;
@end
