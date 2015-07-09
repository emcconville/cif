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
#import "cifio.h"
#import "ciferr.h"


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
"<image>         A system path, or URL, to an image resource. Common image\n"
"                formats, like TIFF, JPEG, and PNG, are supported.\n"
"                Use `-' to read image from standard input.\n"
"<data>          UTF-8 string message. If the first character is an at-sign (@)\n"
"                then argument is assumed to be a path to a file to read data\n"
"                from.\n"
"<number>        A literal number. Integrals, and rational numbers are\n"
"                expected.\n"
"<vector>        A comma-separated list of numbers.\n"
"                Example: \n"
"                   \"0.1,2,3.45\"\n"
"<color>         Common hex-triplet, name, or vector, representing a RGB color.\n"
"                Examples:\n"
"                    #F0F      : Short-hand hex-triplet\n"
"                    #FF00FF   : Hex-triplet\n"
"                    #FF00FFFF : Hex-triplet (plus alpha-channel)\n"
"                    1,0,1     : Vector\n"
"                    1,0,1,1   : Vector (with alpha-channel)\n"
"                    magenta   : X11 color name\n"
"                    rgb(255,0,255) : RGB color function\n"
"                    rgba(255,0,255,1.0) : RGB color function with alpha\n"
"                    hsl(300,100%,50%) : HSL color function\n"
"                    hsla(300,100%,50%,1.0) : HSL color function with alpha\n"
"<affinetransform>\n"
"                A common affine-transformation function. Supported formats\n"
"                are:\n"
"                    matrix(m11,m12,m21,m22,tX,tY)\n"
"                    rotate(D)\n"
"                    rotate(D,X,Y)\n"
"                    scale(X)\n"
"                    scale(X,Y)\n"
"                    translate(X,Y)\n"
"\n"
"Infinite Generators\n"
"-------------------\n"
"Some filters, and generators, create unbounded/infinite images that can not\n"
"be saved to a image file. Providing a `-size <width>x<height>` argument will\n"
"bind the image to the correct size.\n"
"\n"
"    cif CIKaleidoscope -inputImage input.png -size 100x100 output.png\n"
"\n"
"Examples\n"
"--------\n"
"\n"
"  cif CIComicEffect -inputImage input.png output.png\n"
"  cif CIDiscBlur -inputImage - -inputRadius 20 output.tif < input.jpg\n"
"  cif CIStripesGenerator -size 100x100 -inputWidth 10 -inputSharpness 0 \\\n"
"      -inputColor0 \"rgbA(255,0,0,0.1)\"  -inputColor1 BLACK result.png\n"
"\n"
;

void help() {
    usage(); // Calls version
    fprintf(stdout, "%s", _help);
}

void filterApply(CIFilter * filter, NSMutableDictionary *args)
{
    NSDictionary * properties;
    NSString * argument, * key, * valueType, * message;
    [filter setDefaults];
    NSMutableSet * inputKeys = [NSMutableSet setWithArray:[filter inputKeys]];
    NSMutableSet * userGiven = [NSMutableSet setWithArray:[args allKeys]];
    [userGiven minusSet:inputKeys];
    if ([userGiven count] > 0) {
        NSMutableString * userKeyError = [NSMutableString string];
        for ( key in userGiven ) {
            message = [NSString stringWithFormat:@"`-%@'\n", key];
            [userKeyError appendString:message];
        }
        message = [NSString stringWithFormat:@"Unknown filter key:\n%@See `cif list %@'", userKeyError, [filter className]];
        throwException(message);
    }
    
    for (key in [filter inputKeys]) {
        properties = [[filter attributes] valueForKey:key];
        valueType = [properties valueForKey:kCIAttributeClass];
        argument = [args valueForKey:key];
        if (argument == nil) { continue; }
        if ([valueType isEqualToString:@"CIImage"]) {
            [filter setValue:readInputImage(argument) forKey:key];
        } else if ([valueType isEqualToString:@"NSNumber"]) {
            [filter setValue:@([argument doubleValue]) forKey:key];
        } else if ([valueType isEqualToString:@"CIVector"]) {
            [filter setValue:readInputVector(argument) forKey:key];
        } else if ([valueType isEqualToString:@"NSData"]) {
            [filter setValue:readInputMessage(argument) forKey:key];
        } else if ([valueType isEqualToString:@"CIColor"]) {
            [filter setValue:readInputColor(argument) forKey:key];
        } else if ([valueType isEqualToString:@"NSAffineTransform"]) {
            [filter setValue:readInputTransform(argument) forKey:key];
        } else if ([valueType isEqualToString:@"NSString"]) {
            [filter setValue:argument forKey:key];
        } else {
            message = [NSString stringWithFormat:@"Don't know how to handle -%@.", key];
            throwException(message);
        }
    }
    // Perhaps print out the ignored keys?
}


int main(int argc, const char * argv[]) {
    int RETURN_VALUE = 0;
    @autoreleasepool {
        if (argc < 2) { usage(); return 1; }
        
        /* Prototype locals */
        NSString
        * filterName,
        * message,
        * outputPath,
        * command,
        * extent;

        NSMutableDictionary * args;

        NSURL * outputURL;
        
        CIFilter * filter;
        CIImage * outputImage;
        NSArray * userFilters;
        
        @try {
            /** Boot world **/
            loadCifBundles();
        /** Read user input **/
        
        /** Scan for special commands **/
        command = [NSString stringWithUTF8String:argv[1]];
        if ([command isEqualToString:@"list"]) {
            if (argc == 3) {
                NSString * listFilter = [NSString stringWithUTF8String:argv[2]];
                listFilterArgumentsFor(listFilter);
            } else {
                listFilters();
            }
            return 0;
        } else if ([command isEqualToString:@"help"]) {
            help();
            return 0;
        } else if ([command isEqualToString:@"-h"]) {
            help();
            return 0;
        } else if ([command isEqualToString:@"version"]) {
            version();
            return 0;
        } else if ([command isEqualToString:@"-v"]) {
            version();
            return 0;
        }

        userFilters = parseArguments(argv, argc);
        for (NSUInteger i = 0; i < [userFilters count]; ) {
            args = [userFilters objectAtIndex:i];
            filterName = [args objectForKey:@"filter"];
            if (filterName) {
                [args removeObjectForKey:@"filter"];
            } else {
                throwException(@"Core Image Filter missing");
            }
            outputPath = [args valueForKey:@"outputImage"];
            if (outputPath) {
                [args removeObjectForKey:@"outputImage"];
            }
            extent = [args valueForKey:@"size"];
            if (extent) {
                [args removeObjectForKey:@"size"];
            }
            // Allocated filter
            if ( i > 0 ) {
                // For filter chaining
                outputImage = [filter outputImage];
                filter = [CIFilter filterWithName:filterName];
                [filter setDefaults];
                [filter setValue:outputImage forKey:kCIInputImageKey];
            } else {
                // Create first filter
                filter = [CIFilter filterWithName:filterName];
                [filter setDefaults];
            }
            // Check if the filter was found.
            if (filter == nil) {
                message = [NSString stringWithFormat:@"Unknown filter `%@'", filterName];
                throwException(message);
            }
            // Apply all given input arguments to filter.
            filterApply(filter, args);
            i++;
            // Check if we are writing output.
            if (outputPath != nil) {
                outputURL = toWriteableURL(outputPath);
                outputImage = [filter outputImage];
                if (outputImage) {
                    if (CGRectIsInfinite([outputImage extent])) {
                        /* Attempt to read -size, as new image is unbounded */
                        if (extent == nil) {
                            throwException(@"Output image is infinite. Please difine `-size <width>x<height>' argument.");
                        }
                        outputImage = [outputImage imageByCroppingToRect:readInputSize(extent)];
                    }
                    dumpToFile(outputImage, outputURL);
                } else {
                    throwException(@"Unable to read resulting output image");
                } // if output image
            } else if (i == [userFilters count]) {
                // No output
                throwException(@"Output image is missing");
            }
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
