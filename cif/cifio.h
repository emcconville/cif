//
//  cifio.h
//  cif
//
//  Created by Eric McConville on 6/29/15.
//  Copyright (c) 2015 Eric McConville. All rights reserved.
//

#ifndef __cif__cifio__
#define __cif__cifio__

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import "ciferr.h"

#pragma mark - Application Info

#define xstr(s) str(s)
#define str(s) #s

#ifndef CIF_VERSION
#define CIF_VERSION "1.dev"
#endif

#ifndef CIF_RELEASE_DATE
#define CIF_RELEASE_DATE "2015-06-06"
#endif

#ifndef CIF_RELEASE_URL
#define CIF_RELEASE_URL "https://github.com/emcconville/cif"
#endif

#pragma mark Convert helpers

/**
 * @brief Helper method to convert NSString to NSURL
 * @discussion Given string of "STDOUT" will be converted to system
 *             file descriptors. Does not check to see if filename is reachable.
 * @param filename Path to convert to URL
 * @return NSURL
 */
NSURL * toURL(NSString * filename);

/**
 * @brief Helper method for reading user file-path
 * @discussion Calls `toURL`, but also checks if the uri is reachable.
 * @see toURL
 * @param filename Path to read source image
 * @return NSURL
 */
NSURL * toReadableURL(NSString * filename);


/**
 * @brief Helper method for converting user out-path to URL.
 * @discussion Calls `toURL`, but also checks if the uri is reachable.
 * @see toURL
 * @param filename Path to read source image
 * @return NSURL
 */
NSURL * toWriteableURL(NSString * filename);

#pragma mark Input

NSMutableArray * parseArguments(const char * argv[], int argc);

/**
 * @brief Read user image from File Descriptor.
 * @discussion Application will halt until the EOF is read from stdin.
 * @returns CIImage or nil
 */
CIImage * readStandardInputImage();

/**
 * @brief Read user image at given file path
 * @discussion Standard POSIX URI protocols are expected, and will verify path
 *             is reachable. Loads content of URI into CIImage
 *
 *             If filepath begins with 'PATTERN:', then assume we're
 *             loading a embeded pattern/tile image
 *
 * @param filename POSIX path to load resource
 * @returns CIImage
 * @throws Exception when CIImage is unable to be allocated
 */
CIImage * readInputImage(NSString * filename);

/**
 * @brief Load contents of file-path into NSData
 * @param filename Path to system file
 * @returns NSData
 */
NSData * readInputMessageFromFile(NSString * filename);

/**
 * @brief Convert user input into data blob
 * @dicussion Literal strings are encoded into UTF-8. If a input messages
 *            starts with a `@' character, then it's assumed the input message
 *            is a filename, and will read the contents of a fill @ path.
 * @param message string, or URI, to read data
 * @return NSData
 */
NSData * readInputMessage(NSString * message);

/**
 * @brief Read user input and create vector
 * @dicussion Expecting users to input vectors as comma-separated lists,
 *            this method replaces commas with spaces, and feeds them
 *            to CIVector.
 *
 *            "0,1,2" => "[0 1 2]" => "CIVector * {.X=0, .Y=1, .Z=2}"
 *
 * @param token String to parse for vector
 * @returns CIVector
 * @todo Raise exception on error
 */
CIVector * readInputVector(NSString * token);

/**
 * @brief Convert user input into CIColor object.
 * @discussion The following color formats are supported:
 *
 *             <ul>
 *             <li><b>VECTOR</b> - <i>1.0,0.5,1.0</i></li>
 *             <li><b>HEX RGB</b> - <i>#F0F</i></li>
 *             <li><b>HEX RRGGBB</b> - <i>#FF00FF</i></li>
 *             <li><b>HEX RRGGBBAA</b> - <i>#FF00FFFF</i></li>
 *             <li><b>X11 Color names</b> - <i>Fuchsia</i></li>
 *             <li><b>RGB functions</b> - <i>rgb(255, 00, 255)</i></li>
 *             <li><b>RGBA functions</b> - <i>rgb(255, 00, 255, 0.75)</i></li>
 *             <li><b>HSL functions</b> - <i>hsl(200, 50%, 50%)</i></li>
 *             <li><b>HSLA functions</b> - <i>hsl(200, 50%, 50%, 0.75)</i></li>
 *             </ul>
 *
 * @param token Color string
 * @return CIColor or nil
 * @todo Can be optimized
 */
CIColor * readInputColor(NSString * token);

/**
 * @brief Like <b>readInputVector</b>, but supports WxH format.
 * @param size String to determine dimensions
 * @return CGRect
 */
CGRect readInputSize(NSString * size);

/**
 * @brief Create affine transform from user input.
 * @discussion Scans one, or more, of the following formats:
 *
 *             <ul>
 *             <li>matrix(m11,m12,m21,m22,tX,tY)</li>
 *             <li>rotate(D)</li>
 *             <li>rotate(D,X,Y)</li>
 *             <li>scale(X)</li>
 *             <li>scale(X,Y)</li>
 *             <li>translate(X,Y)</li>
 *             </ul>
 *
 * @param token User literal string to be parsed.
 * @returns NSAffineTransform
 */
NSAffineTransform * readInputTransform(NSString * token);


#pragma mark Output

/**
 * @brief Write CIImage to file path
 * @discussion Will attempt to match the path file extension, and support the
 *             following formats:
 *
 *             <ul>
 *             <li>PNG</li>
 *             <li>JPG</li>
 *             <li>TIFF</li>
 *             <li>PNG</li>
 *             <li>BMP</li>
 *             </ul>
 *
 * @param source Image instance
 * @param uri Destination path
 * @throws Exception if format not supported, or unable to write to path
 */
void dumpToFile(CIImage * source, NSURL * uri);

/**
 * @brief Write string to stdout
 * @param str Message to display
 */
void dumpToSTDOUT(NSString * str);

/**
 * @brief Write string to stderr
 * @param str Message to display
 */
void dumpToSTDERR(NSString * str);

/**
 * @brief Display all CIFilters
 * @discussion Limited list of filters by category.
 */
void listFilters();

void listFilterArgumentsFor(NSString * filterName);

#pragma mark - Boot World

void loadCifBundles();

#endif /* defined(__cif__cifio__) */
