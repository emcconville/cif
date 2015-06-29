//
//  cifio.c
//  cif
//
//  Created by Eric McConville on 6/29/15.
//  Copyright (c) 2015 Eric McConville. All rights reserved.
//

#include "cifio.h"
#include "CIColor+X11ColorName.h"
#include "CIImage+PatternName.h"

#pragma mark Convert helpers

NSURL * toURL(NSString * filename)
{
    NSURL * uri;
    if ([filename caseInsensitiveCompare:@"STDOUT"] == NSOrderedSame) {
        uri = [NSURL fileURLWithPath:@"/dev/stdout" isDirectory:NO];
    } else {
        uri = [NSURL fileURLWithPath:filename isDirectory:NO];
    }
    return uri;
};

NSURL * toReadableURL(NSString * filename)
{
    NSURL * uri = toURL(filename);
    NSError * err;
    NSString * message;
    if ([uri checkResourceIsReachableAndReturnError:&err] == NO) {
        message = [NSString stringWithFormat:@"%ld :: %@\n%@",
                   [err code],
                   [err domain],
                   [err localizedDescription]];
        throwException(message);
    }
    return uri;
};


NSURL * toWriteableURL(NSString * filename)
{
    return toURL(filename);
};


#pragma mark Input

NSMutableArray * parseArguments(const char * argv[], int argc)
{
    NSString * keyword, * value;
    NSMutableDictionary * kwargs = [[NSMutableDictionary alloc] init];
    NSMutableArray * stack = [[NSMutableArray alloc] init];
    NSArray * filters = [CIFilter filterNamesInCategories:nil];
    for (int index = 1; index < argc; index++) {
        keyword = [NSString stringWithUTF8String:argv[index]];
        if ([keyword hasPrefix:@"-"] && [keyword length] > 1) {
            // We have a keyword
            index++;
            if (index >= argc) {
                // Not a keyword value
                value = [NSString stringWithFormat:@"%@ argument expecting value", keyword];
                throwException(value);
            }
            value = [NSString stringWithUTF8String:argv[index]];
            keyword = [keyword substringFromIndex:1];
        } else if ([filters indexOfObject:keyword] != NSNotFound) {
            // Assume first instance ommits `-filter'
            value = keyword;
            keyword = @"filter";
        } else {
            if ([kwargs objectForKey:@"outputImage"] == nil) {
                // Assume last token is output file
                value = [keyword isEqualTo:@"-"] ? @"STDOUT" : keyword;
                keyword = @"outputImage";
            } else {
                value = [NSString stringWithFormat:@"Unexpected argument `%@'", keyword];
                throwException(value);
            }
        }
        if ([kwargs objectForKey:keyword] == nil) {
            [kwargs setObject:[value copy] forKey:[keyword copy]];
        } else {
            if ([keyword isEqualTo:@"filter"]) {
                [stack addObject:[kwargs mutableCopy]];
                kwargs = [[NSMutableDictionary alloc] init];
                [kwargs setObject:[value copy] forKey:[keyword copy]];
            } else {
                throwException(@"Conflicting arguments, remove duplicate keys");
            }
        }
    }
    if ([kwargs count] > 0) {
        [stack addObject:kwargs];
    }
    return stack;
}


CIImage * readStandardInputImage()
{
    NSFileHandle *stdInput = [NSFileHandle fileHandleWithStandardInput];
    NSData * blob = [NSData dataWithData:[stdInput readDataToEndOfFile]];
    CIImage * source = [CIImage imageWithData:blob];
    return source;
};


CIImage * readInputImage(NSString * filename)
{
    CIImage * source;
    /* Scan for known pattern prefix */
    NSString * patternProtocol = @"pattern:";
    NSUInteger patternLength= [patternProtocol length]; // TODO refactro this
    if ([filename length] > patternLength && [[filename substringToIndex:patternLength] caseInsensitiveCompare:patternProtocol] == NSOrderedSame) {
        source = [CIImage imageWithName:[filename substringFromIndex:patternLength]];
    } else if ([filename caseInsensitiveCompare:@"STDIN"] == NSOrderedSame) {
        source = readStandardInputImage();
    } else if ([filename isEqualToString:@"-"]) {
        source = readStandardInputImage();
    } else {
        NSURL * uri = toReadableURL(filename);
        source = [CIImage imageWithContentsOfURL:uri];
    }
    if (source == nil) {
        throwException(@"Unable to read input image");
    }
    return source;
};


NSData * readInputMessageFromFile(NSString * filename)
{
    return [NSData dataWithContentsOfURL:toURL(filename)];
};


NSData * readInputMessage(NSString * message)
{
    NSData * data;
    if ([[message substringToIndex:1] isEqualToString:@"@"]) {
        data = readInputMessageFromFile([message substringFromIndex:1]);
    } else {
        data = [message dataUsingEncoding:NSUTF8StringEncoding];
    }
    return data;
};


CIVector * readInputVector(NSString * token)
{
    NSString * vectorFormat = [[NSString stringWithFormat:@"[%@]", token] stringByReplacingOccurrencesOfString:@"," withString:@" "];
    return [CIVector vectorWithString:vectorFormat];
};



CIColor * readInputColor(NSString * token)
{
    CIColor * color;
    CIVector * vector;
    // All CIColor+X11ColorName methods require lowercase.
    // Let's do it once, and assume it's been done before.
    token = [token lowercaseString];
    if ([token hasPrefix:@"#"]) {
        // We have a hex color
        token = [token substringFromIndex:1]; // Get rid of '#'
        color = [CIColor colorWithHexString:token];
    } else if ([token hasPrefix:@"rgb"]) {
        color = [CIColor colorWithRgbString:token];
    } else if ([token hasPrefix:@"hsl"]) {
        color = [CIColor colorWithHslString:token];
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
    if (color == nil) {
        NSString * message = [NSString stringWithFormat:@"Unable to understand color string `%@'", token];
        throwException(message);
    }
    return color;
};


CGRect readInputSize(NSString * size)
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


NSAffineTransform * readInputTransform(NSString * token)
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

void dumpToFile(CIImage * source, NSURL * uri)
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
    } else if ([[uri description] isEqualTo:@"file:///dev/stdout"]) {
        // Let's default to PNG until we can figure out how we should
        // handle anonymous formats. PNG being the correct OS default.
        blob = [rep representationUsingType:NSPNGFileType properties:nil];
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


void dumpToSTDOUT(NSString * str)
{
    [str writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:nil];
};


void dumpToSTDERR(NSString * str)
{
    [str writeToFile:@"/dev/stderr" atomically:NO encoding:NSUTF8StringEncoding error:nil];
};

void listFilters()
{
    for (NSString * filter in [CIFilter filterNamesInCategories:nil]) {
        dumpToSTDOUT([NSString stringWithFormat:@"%@\n", filter]);
    }
}

void listFilterArgumentsFor(NSString * filterName)
{
    CIFilter * f = [CIFilter filterWithName:filterName];
    NSString * padding = [[[NSString alloc] init] stringByPaddingToLength:[filterName length] withString:@"-" startingAtIndex:0];
    NSString * message = [NSString stringWithFormat:@"\n%@\n%@\n%@\n\n", filterName, padding, [CIFilter localizedDescriptionForFilterName:filterName]];
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

#pragma mark - Boot World

void loadCifBundles()
{
    /* Prototype locals */
    NSBundle * package;
    Class principalClass;
    NSString
    * directory,
    * cifBundleDir = @"Application Support/cif/Filters",
    * currentPath = nil,
    * currentBundlePath = nil;
    NSArray * searchPath;
    NSEnumerator
    * searchEnum,
    * dirEnum;
    // Search ~/Library, /System/Library, and /Network/Library
    searchPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                     NSAllDomainsMask - NSSystemDomainMask,
                                                     YES);
    searchEnum = [searchPath objectEnumerator];
    while (currentPath = [searchEnum nextObject]) {
        directory = [currentPath stringByAppendingPathComponent:cifBundleDir];
        dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:directory];
        while ( currentBundlePath =  [dirEnum nextObject]) {
            if ([currentBundlePath hasSuffix:@".bundle"]) {
                currentPath = [directory stringByAppendingPathComponent:currentBundlePath];
                // Load bundle
                package = [NSBundle bundleWithPath:currentPath];
                if ([package load]) {
                    // Initialize principal class (if given)
                    principalClass = [package principalClass];
                    if (principalClass) {
                        (void)[[principalClass alloc] init];
                    } // principalClass
                } // package load
            } // SomeName.bundle
        } // In Filters
    } // Search path
}
