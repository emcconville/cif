//
//  main.m
//  cif
//
//  Created by Eric McConville on 6/16/15.
//  Copyright (c) 2015 Eric McConville. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import "CIColor+X11ColorName.h"
#import "CIImage+PatternName.h"

#pragma mark Exceptions

/**
 * @brief Helper function to allocate & throw exceptions from given string.
 * @param message String to populate `reason' attribute on exception.
 * @throws NSException generated exception from message.
 */
void (^throwException)(NSString *) = ^(NSString *message) {
    NSException * exception = [NSException exceptionWithName:@"CIF exception"
                                                      reason:message
                                                    userInfo:nil];
    [exception raise];
};


#pragma mark Convert helpers


/**
 * @brief Helper method to convert NSString to NSURL
 * @discussion Given string of "STDIN" & "STDOUT" will be converted to system
 *             file descriptors. Does not check to see if filename is reachable.
 * @param filename Path to convert to URL
 * @return NSURL
 * @todo STDIN & STDOUT are not working at the moment
 */
NSURL * (^toURL)(NSString *) = ^(NSString * filename)
{
    NSURL * uri;
    if ([filename caseInsensitiveCompare:@"STDIN"] == NSOrderedSame) {
        uri = [NSURL fileURLWithPath:@"/dev/stdin" isDirectory:NO];
    } else if ([filename caseInsensitiveCompare:@"STDOUT"] == NSOrderedSame) {
        uri = [NSURL fileURLWithPath:@"/dev/stdout" isDirectory:NO];
    } else {
        uri = [NSURL fileURLWithPath:filename isDirectory:NO];
    }
    return uri;
};


/**
 * @brief Helper method for reading user file-path
 * @discussion Calls `toURL`, but also checks if the uri is reachable.
 * @see toURL
 * @param filename Path to read source image
 * @return NSURL
 */
NSURL * (^toReadableURL)(NSString *) = ^(NSString * filename)
{
    NSURL * uri = toURL(filename);
    NSError * err;
    if ([uri checkResourceIsReachableAndReturnError:&err] == NO) {
        NSString * message = [NSString stringWithFormat:@"%ld :: %@", [err code], [err domain]];
        throwException(message);
    }
    return uri;
};


/**
 * @brief Helper method for converting user out-path to URL.
 * @discussion Calls `toURL`, but also checks if the uri is reachable.
 * @see toURL
 * @param filename Path to read source image
 * @return NSURL
 */
NSURL * (^toWriteableURL)(NSString *) = ^(NSString * filename)
{
    return toURL(filename);
};


/**
 * @brief Convert four-bit hex (0xF) to number between 0.0 & 1.0
 * @param bit Hex string to be converted
 * @return CGFloat
 */
CGFloat (^fourBitToDouble)(NSString *) = ^(NSString * bit)
{
    unsigned int unsigned_bit;
    [[NSScanner scannerWithString:bit] scanHexInt:&unsigned_bit];
    return unsigned_bit  / 15.0;
};

/**
 * @brief Convert eight-bit hex (0xFF) to number between 0.0 & 1.0
 * @param bits Hex string to be converted
 * @return CGFloat
 */
CGFloat (^eightBitToDouble)(NSString *) = ^(NSString * bits)
{
    unsigned int unsigned_bit;
    [[NSScanner scannerWithString:bits] scanHexInt:&unsigned_bit];
    return unsigned_bit  / 255.0;
};

/**
 * @brief Convert number value to common double range.
 * @discussion String percent, and rational  values are convert
 * @param token String to evaluate with NSNumberFormatter
 */
CGFloat (^stringToPercent)(NSString *) = ^(NSString *token)
{
    NSNumber * result;
    NSNumberFormatter * rFormatter = [[NSNumberFormatter alloc] init];
    NSNumberFormatter * pFormatter = [[NSNumberFormatter alloc] init];
    [rFormatter setFormatterBehavior:NSNumberFormatterBehaviorDefault];
    [rFormatter setNumberStyle:NSNumberFormatterNoStyle];
    [pFormatter setFormatterBehavior:NSNumberFormatterBehaviorDefault];
    [pFormatter setNumberStyle:NSNumberFormatterPercentStyle];
    result = [pFormatter numberFromString:token];
    if ( result == nil ) {
        result = [rFormatter numberFromString:token];
        if ( result == nil ) {
            NSString * format = @"Unable to evaluate number value `%@'";
            NSString * message = [NSString stringWithFormat:format, token];
            throwException(message);
        }
        if ([result doubleValue] > 1.0) {
            result = [NSNumber numberWithDouble:([result doubleValue] / 255.0)];
        }
    }
    return (CGFloat)[result doubleValue];
};


#pragma mark Input


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
CIImage * (^readInputImage)(NSString *) = ^(NSString * filename) {
    CIImage * source;
    /* Scan for known pattern prefix */
    NSString * patternProtocol = @"pattern:";
    NSUInteger patternLength= [patternProtocol length];
    if ([[filename substringToIndex:patternLength] caseInsensitiveCompare:patternProtocol] == NSOrderedSame) {
        source = [CIImage imageWithName:[filename substringFromIndex:patternLength]];
    } else {
        NSURL * uri = toReadableURL(filename);
        source = [CIImage imageWithContentsOfURL:uri];
    }
    if (source == nil) {
        throwException(@"Unable to read input image");
    }
    return source;
};


/**
 * @brief Load contents of file-path into NSData
 * @param filename Path to system file
 * @returns NSData
 */
NSData * (^readInputMessageFromFile)(NSString *) = ^(NSString * filename) {
    return [NSData dataWithContentsOfURL:toURL(filename)];
};


/**
 * @brief Convert user input into data blob
 * @dicussion Literal strings are encoded into UTF-8. If a input messages
 *            starts with a `@' character, then it's assumed the input message
 *            is a filename, and will read the contents of a fill @ path.
 * @param message string, or URI, to read data
 * @return NSData
 */
NSData * (^readInputMessage)(NSString *) = ^(NSString * message) {
    NSData * data;
    if ([[message substringToIndex:1] isEqualToString:@"@"]) {
        data = readInputMessageFromFile([message substringFromIndex:1]);
    } else {
        data = [message dataUsingEncoding:NSUTF8StringEncoding];
    }
    return data;
};

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
CIVector * (^readInputVector)(NSString *) = ^(NSString * token)
{
    NSString * vectorFormat = [[NSString stringWithFormat:@"[%@]", token] stringByReplacingOccurrencesOfString:@"," withString:@" "];
    return [CIVector vectorWithString:vectorFormat];
};


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
 *             </ul>
 *
 *             Color functions [ <i>rgb(), hsl(), hsv(), & etc.</i> ] are planned.
 * @param token Color string
 * @return CIColor or nil
 * @todo Can be optimized
 */
CIColor * (^readInputColor)(NSString *) = ^(NSString * token)
{
    CIColor * color;
    CIVector * vector;
    CGFloat R,G,B,A;
    if ([token characterAtIndex:0] == '#') {
        // We have a hex color
        token = [token substringFromIndex:1]; // Get rid of '#'
        long length = [token length];
        if ( length == 3 ) {
            // RGB
            R = fourBitToDouble([token substringWithRange:NSMakeRange(0,1)]);
            G = fourBitToDouble([token substringWithRange:NSMakeRange(1,1)]);
            B = fourBitToDouble([token substringWithRange:NSMakeRange(2,1)]);
            
            color = [CIColor colorWithRed:R green:G blue:B];
        } else if ( length == 6 ) {
            // RRGGBB
            R = eightBitToDouble([token substringWithRange:NSMakeRange(0,2)]);
            G = eightBitToDouble([token substringWithRange:NSMakeRange(2,2)]);
            B = eightBitToDouble([token substringWithRange:NSMakeRange(4,2)]);
            
            color = [CIColor colorWithRed:R green:G blue:B];
        } else if ( length == 8 ) {
            // RRGGBBAA
            R = eightBitToDouble([token substringWithRange:NSMakeRange(0,2)]);
            G = eightBitToDouble([token substringWithRange:NSMakeRange(2,2)]);
            B = eightBitToDouble([token substringWithRange:NSMakeRange(4,2)]);
            A = eightBitToDouble([token substringWithRange:NSMakeRange(6,2)]);
            color = [CIColor colorWithRed:R green:G blue:B alpha:A];
            
        } else {
            throwException(@"Unable to read color format.");
        }
    } else {
        // Try to load color by name (brute-force = refactor later)
        color = [CIColor colorWithName:token];
        if (color == nil) {
            // Assume vector
            vector = readInputVector(token);
            if ([vector count] == 3) {
                color = [CIColor colorWithRed:vector.X
                                        green:vector.Y
                                         blue:vector.Z];
            } else if ([vector count] == 4) {
                color = [CIColor colorWithRed:vector.X
                                        green:vector.Y
                                         blue:vector.Z
                                        alpha:vector.W];
            } else {
                throwException(@"Expecting color values as R,G,B,A format");
            }
        }
    }
    return color;
};


/**
 * @brief Like <b>readInputVector</b>, but supports WxH format.
 * @param size String to determine dimensions
 * @return CGRect
 */
CGRect (^readInputSize)(NSString *) = ^(NSString * size)
{
    // For W,H
    size = [size stringByReplacingOccurrencesOfString:@"," withString:@" "];
    // For WxH
    size = [size stringByReplacingOccurrencesOfString:@"x" withString:@" "];
    CIVector * vector = [CIVector vectorWithString:[NSString stringWithFormat:@"[%@]", size]];
    if ( [vector count] != 2 ) {
        throwException(@"Unable to read size value.");
    }
    return CGRectMake(0, 0, vector.X, vector.Y);
};


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
NSAffineTransform * (^readInputTransform)(NSString *) = ^(NSString * token)
{
    // The transform envelope to return
    NSAffineTransform * transform = [NSAffineTransform transform];
    // Temporary transform to append to envelope
    NSAffineTransform * tmpTransform;
    // Data structure to build transform from matrix data
    NSAffineTransformStruct tmpStruct;
    NSCharacterSet * ignore = [NSCharacterSet characterSetWithCharactersInString:@" \t\n\r"];
    NSCharacterSet * open = [NSCharacterSet characterSetWithCharactersInString:@"("];
    NSCharacterSet * close = [NSCharacterSet characterSetWithCharactersInString:@")"];
    
    NSScanner * scanner = [NSScanner scannerWithString:token];
    [scanner setCharactersToBeSkipped:ignore];
    [scanner setCaseSensitive:NO];
    NSString * command;
    NSString * args;
    CIVector * argv;
    while ( [scanner isAtEnd] == NO) {
        [scanner scanUpToCharactersFromSet:open intoString:&command];
        [scanner setScanLocation:[scanner scanLocation]+1];
        [scanner scanUpToCharactersFromSet:close intoString:&args];
        [scanner setScanLocation:[scanner scanLocation]+1];
        tmpTransform = [NSAffineTransform transform];
        if ([command isEqualToString:@"matrix"]) {
            tmpStruct = [tmpTransform transformStruct];
            if (sscanf([args cStringUsingEncoding:NSASCIIStringEncoding],
                       "%lg,%lg,%lg,%lg,%lg,%lg",
                       &tmpStruct.m11,
                       &tmpStruct.m12,
                       &tmpStruct.m21,
                       &tmpStruct.m22,
                       &tmpStruct.tX,
                       &tmpStruct.tY) == 6) {
                [tmpTransform setTransformStruct:tmpStruct];
            } else {
                throwException(@"Matrix transform expecting 6 arguments");
            }
        } else if ( [command isEqualToString:@"rotate"]) {
            argv = readInputVector(args);
            if ([argv count] == 1) {
                [tmpTransform rotateByDegrees:argv.X];
            } else if ([argv count] == 3) {
                [tmpTransform translateXBy:argv.Y yBy:argv.Z];
                [tmpTransform rotateByDegrees:argv.X];
            } else {
                throwException(@"Rotate transform expecting 1, or 3 arguments");
            }
        } else if ( [command isEqualToString:@"scale"]) {
            argv = readInputVector(args);
            if ([argv count] == 1) {
                [tmpTransform scaleBy:argv.X];
            } else if ([argv count] == 2) {
                [tmpTransform scaleXBy:argv.X yBy:argv.Y];
            } else {
                throwException(@"Scale expecting 1, or 2 arguments");
            }
        } else if ( [command isEqualToString:@"translate"]) {
            argv = readInputVector(args);
            if ([argv count] == 2) {
                [tmpTransform translateXBy:argv.X yBy:argv.Y];
            } else {
                throwException(@"Translate expecting X & Y");
            }
        } else {
            throwException(@"Unrecognized transform function");
        }
        [transform appendTransform:tmpTransform];
    }
    return transform;
};


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
void (^dumpToFile)(CIImage *, NSURL *) = ^(CIImage * source, NSURL * uri)
{
    NSData * blob;
    NSBitmapImageRep * rep = [[NSBitmapImageRep alloc] initWithCIImage:source];
    NSString * ext = [uri pathExtension];
    if ([ext caseInsensitiveCompare:@"PNG"] == NSOrderedSame) {
        blob = [rep representationUsingType:NSPNGFileType properties:nil];
    } else if ([ext caseInsensitiveCompare:@"JPG"] == NSOrderedSame
               || [ext caseInsensitiveCompare:@"JPEG"] == NSOrderedSame) {
        blob = [rep representationUsingType:NSJPEGFileType properties:nil];
    } else if ([ext caseInsensitiveCompare:@"TIF"] == NSOrderedSame
               || [ext caseInsensitiveCompare:@"TIFF"] == NSOrderedSame) {
        blob = [rep representationUsingType:NSTIFFFileType properties:nil];
    } else if ([ext caseInsensitiveCompare:@"GIF"] == NSOrderedSame) {
        blob = [rep representationUsingType:NSGIFFileType properties:nil];
    } else if ([ext caseInsensitiveCompare:@"BMP"] == NSOrderedSame) {
        blob = [rep representationUsingType:NSBMPFileType properties:nil];
    } else {
        NSString * message = [NSString stringWithFormat:@"Don't know how to write to %@ format", [ext uppercaseString]];
        throwException(message);
    }
    if (blob) {
        BOOL okay = [blob writeToURL:uri atomically:NO];
        if (!okay) {
            NSString * message = [NSString stringWithFormat:@"Unable to write to %@", uri];
            throwException(message);
        }
    }
};


/**
 * @brief Write string to stdout
 * @param str Message to display
 */
void (^dumpToSTDOUT)(NSString *) = ^(NSString * str)
{
    [str writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:nil];
};


/**
 * @brief Write string to stderr
 * @param str Message to display
 */
void (^dumpToSTDERR)(NSString *) = ^(NSString * str)
{
    [str writeToFile:@"/dev/stderr" atomically:NO encoding:NSUTF8StringEncoding error:nil];
};

/**
 * @brief Display all CIFilters
 * @discussion Limited list of filters by category.
 * @todo Build complete list
 */
void listFilters()
{
    NSMutableArray * filters = [NSMutableArray array];
    NSArray * categories = [NSArray arrayWithObjects:
                            kCICategoryBlur,
                            kCICategoryColorAdjustment,
                            kCICategoryColorEffect,
                            kCICategoryCompositeOperation,
                            kCICategoryDistortionEffect,
                            kCICategoryGenerator,
                            kCICategoryGradient,
                            kCICategoryHalftoneEffect,
                            kCICategoryReduction,
                            kCICategorySharpen,
                            kCICategoryStylize,
                            kCICategoryTileEffect,
                            kCICategoryTransition,
                            nil];
    for (NSString * category in categories) {
        [filters addObjectsFromArray:[CIFilter filterNamesInCategory:category]];
        if ([filters count] > 0) {
            for (NSString * filter in filters) {
                dumpToSTDOUT([NSString stringWithFormat:@"%@\n", filter]);
            }
        }
        [filters removeAllObjects];
    }
    
}

void listFilterArgumentsFor(NSString * filterName)
{
    CIFilter * f = [CIFilter filterWithName:filterName];
    NSString * message = [NSString stringWithFormat:@"%@\n%@\n%@\n\n", filterName, [[[NSString alloc] init] stringByPaddingToLength:[filterName length] withString:@"-" startingAtIndex:0],[CIFilter localizedDescriptionForFilterName:filterName]];
    dumpToSTDOUT(message);
    NSDictionary * a = [f attributes];
    for ( NSString * attr in a  ) {
        if ([[attr substringToIndex:5] isEqualToString:@"input"]) {
            NSDictionary * properties = [a objectForKey:attr];
            NSString * type = @"";
            NSString * _type = [properties objectForKey:@"CIAttributeClass"];
            NSString * description = @"";
            NSString * _description = [properties objectForKey:@"CIAttributeDescription"];
            NSString * typeDefault = @"";
            NSString * _default = [properties objectForKey:@"CIAttributeDefault"];
            
            if (_type) {
                type = [NSString stringWithFormat:@"<%@> ", [[_type substringFromIndex:2] lowercaseString]];
            }
            if (_description) {
                description = _description;
            }
            if (_default) {
                if ([_type isEqualToString:@"CIVector"]) {
                    CIVector * vector = [properties objectForKey:@"CIAttributeDefault"];
                    switch ([vector count]) {
                        case 1:{
                            _default = [NSString stringWithFormat:@"%g", vector.X];
                            break;
                        }
                        case 2:{
                            _default = [NSString stringWithFormat:@"%g,%g", vector.X, vector.Y];
                            break;
                        }
                        case 3:{
                            _default = [NSString stringWithFormat:@"%g,%g,%g", vector.X, vector.Y, vector.Z];
                            break;
                        }
                        case 4:{
                            _default = [NSString stringWithFormat:@"%g,%g,%g,%g", vector.X, vector.Y, vector.Z, vector.W];
                            break;
                        }
                    }
                } else if ([_type isEqualToString:@"CIColor"]) {
                    CIColor * color = [properties objectForKey:@"CIAttributeDefault"];
                    unsigned int red = (unsigned int)([color red] * 0xFF);
                    unsigned int green = (unsigned int)([color green] * 0xFF);
                    unsigned int blue = (unsigned int)([color blue] * 0xFF);
                    unsigned int alpha = (unsigned int)([color alpha] * 0xFF);
                    if (alpha == 0xFF) {
                        _default = [NSString stringWithFormat:@"#%02X%02X%02X", red, green, blue];
                    } else {
                        _default = [NSString stringWithFormat:@"#%02X%02X%02X%02X", red, green, blue, alpha];
                    }
                }
                typeDefault = [NSString stringWithFormat:@" [Default %@]", _default];
            }
            NSString * line = [NSString stringWithFormat:@" -%@ %@: %@%@\n", attr, type, description, typeDefault];
            dumpToSTDOUT(line);
        }
    }
    dumpToSTDOUT(@"\n");
}


#pragma mark - Application

#define xstr(s) str(s)
#define str(s) #s

#ifndef CIF_VERSION
#define CIF_VERSION 1.0
#endif

#ifndef CIF_RELEASE_DATE
#define CIF_RELEASE_DATE "2015-06-06"
#endif

#ifndef CIF_RELEASE_URL
#define CIF_RELEASE_URL "https://github.com/emcconville/cif"
#endif


static const char * _version = "Version: cif %s %s %s\n"
"Copyright: Copyright (C) 2015 emcconville\n"
"\n";

void version() {
    fprintf(stdout, _version,
            xstr(CIF_VERSION),
            xstr(CIF_RELEASE_DATE),
            xstr(CIF_RELEASE_URL));
}

static const char * _usage = ""
"Usage: cif <CIFilter> [arguments, ...] <file>\n"
"       cif help\n"
"       cif list\n"
"       cif list <CIFilter>\n"
"\n";


void usage() {
    version();
    fprintf(stdout, "%s", _usage);
};


static const char * _help = "\n"
"Commands\n"
"--------\n"
"\n"
"<CIFilter>      Execute CoreImage Filter against given arguments. Each filter\n"
"                requires unique parameters. Run `list <filter>' to print all\n"
"                expected arguments.\n"
"help, -h        This help message.\n"
"list            List all CoreImage Filters\n"
"list <CIFilter> Display description of Core Image filter, and list all input\n"
"                parameters. Each parameter hints expected format, and default\n"
"                value.\n"
"version, -v     Print current version header.\n"
"\n"
"Types\n"
"-----\n"
"\n"
"<image>         A system path, or URL, to an image resource.\n"
"<data>          UTF-8 string message. If the first character is an at-sign (@)\n"
"                then argument is assumed to be a path to a file to read data\n"
"                from.\n"
"<number>        A literal number. Integreals, and rational numbers are\n"
"                expected.\n"
"<vector>        A comma-separated list of numbers. Example: \"0.1,2,3.45\"\n"
"<color>         Common hex-triplet, name, or vector, representing a RGB color.\n"
"                Examples:\n"
"                     #F0F : Short-hand hex-triplet\n"
"                  #FF00FF : Hex-triplet\n"
"                #FF00FFFF : Hex-triplet (plus alpha-channel)\n"
"                    1,0,1 : Vector\n"
"                  1,0,1,1 : Vector (with alpha-channel)\n"
"                  magenta : X11 color name\n"
"<affine> or\n"
"<transform>     A common affine-transfromation function. Supported fromats\n"
"                are:\n"
"                    matrix(m11,m12,m21,m22,tX,tY)\n"
"                    rotate(D)\n"
"                    rotate(D,X,Y)\n"
"                    scale(X)\n"
"                    scale(X,Y)\n"
"                    translate(X,Y)\n"
"\n"
;

void help() {
    usage(); // Calls version
    fprintf(stdout, "%s", _help);
}

int main(int argc, const char * argv[]) {
    int RETURN_VALUE = 0;
    @autoreleasepool {
        if (argc < 2) { usage(); return 1; }
        const char * action = argv[1];
        const char * last = argv[argc-1];
        
        /* Prototype locals */
        NSArray * inputKeys;
        NSString
        * argument,
        * filterName,
        * key,
        * message,
        * outputPath,
        * _type;
        NSMutableDictionary * args;
        NSDictionary * properties;
        NSURL * outputURL;
        
        CGRect requiredRect;
        
        CIFilter *filter;
        CIImage *outputImage;
        
        @try {
        /** Read user input **/
        args = [[[NSUserDefaults standardUserDefaults] volatileDomainForName:NSArgumentDomain] mutableCopy];
        /** ^^ this should be a real argument parser **/
        
        /** Get required filter operation **/
        filterName = [args valueForKey:@"filter"];
        if(filterName) {
            [args removeObjectForKey:@"filter"];
        } else {
            filterName = [NSString stringWithUTF8String:action];
        }
        if ([filterName isEqualToString:@"list"]) {
            if (argc == 3) {
                NSString * listFilter = [NSString stringWithUTF8String:argv[2]];
                listFilterArgumentsFor(listFilter);
            } else {
                listFilters();
            }
            return 0;
        } else if ([filterName isEqualToString:@"help"] || [filterName isEqualToString:@"-h"]) {
            help();
            return 0;
        } else if ([filterName isEqualToString:@"version"] || [filterName isEqualToString:@"-v"]) {
            version();
            return 0;
        }
        if ([[filterName substringToIndex:2] isEqualToString:@"CI"] == NO) {
            usage();
            throwException(@"Expecting Core Image Filter");
        }
        
        /* Get required output location (input is optional) */
        outputPath = [args valueForKey:@"outputImage"];
        if (outputPath) {
            [args removeObjectForKey:@"outputImage"];
        } else if (argc > 2) {
            // Assume last given argument is destination.
            outputPath = [NSString stringWithUTF8String:last];
            if ([outputPath isEqualToString:filterName]) {
                // This should be unreachable, but I don't trust myself.
                message = [NSString stringWithFormat:@"Confusion %@ writes to self %@?", outputPath, filterName];
                throwException(message);
            }
        }
        outputURL = toWriteableURL(outputPath);
        if (filterName != nil && outputPath != nil) {
            filter = [CIFilter filterWithName:filterName];
            if (filter) {
                [filter setDefaults];
                
                inputKeys = [filter inputKeys];
                for (key in inputKeys) {
                    properties = [[filter attributes] valueForKey:key];
                    _type = [properties valueForKey:kCIAttributeClass];
                    argument = [args valueForKey:key];
                    if (argument == nil) { continue; }
                    if ([_type isEqualToString:@"CIImage"]) {
                        [filter setValue:readInputImage(argument) forKey:key];
                    } else if ([_type isEqualToString:@"NSNumber"]) {
                        [filter setValue:@([argument doubleValue]) forKey:key];
                    } else if ([_type isEqualToString:@"CIVector"]) {
                        [filter setValue:readInputVector(argument) forKey:key];
                    } else if ([_type isEqualToString:@"NSData"]) {
                        [filter setValue:readInputMessage(argument) forKey:key];
                    } else if ([_type isEqualToString:@"CIColor"]) {
                        [filter setValue:readInputColor(argument) forKey:key];
                    } else if ([_type isEqualToString:@"NSAffineTransform"]) {
                        [filter setValue:readInputTransform(argument) forKey:key];
                    } else {
                        message = [NSString stringWithFormat:@"Don't know how to handle -%@.", key];
                        throwException(message);
                    }
                }
                
                if (outputPath != nil) {
                    outputImage = [filter outputImage];
                    if (outputImage) {
                        if (CGRectIsInfinite([outputImage extent])) {
                            /* Attempt to read -size, as new image is unbounded */
                            argument = [args valueForKey:@"size"];
                            if (argument == nil) {
                                throwException(@"Output image is infinite, did you define `-size'?");
                            }
                            requiredRect = readInputSize(argument);
                            outputImage = [outputImage imageByCroppingToRect:requiredRect];
                        }
                        dumpToFile(outputImage, outputURL);
                    } else {
                        throwException(@"Unable to read resulting output image");
                    }
                } else {
                    throwException(@"Missing -outputImage");
                }
            } else {
                usage();
                message = [NSString stringWithFormat:@"Core Image Filter `%@'", filterName];
                throwException(message);
            }
        } else {
            usage();
            RETURN_VALUE = 1;
        }
    } // @ try
    @catch (NSException * err) {
        message = [NSString stringWithFormat:@"%@\n",[err reason]];
        dumpToSTDERR(message);
        RETURN_VALUE = 1;
    }
    } // @autorelease
    return RETURN_VALUE;
}
