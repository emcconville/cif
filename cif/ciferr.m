//
//  ciferr.c
//  cif
//
//  Created by Eric McConville on 6/29/15.
//  Copyright (c) 2015 Eric McConville. All rights reserved.
//

#include "ciferr.h"

#pragma mark Exceptions

/**
 * @brief Helper function to allocate & throw exceptions from given string.
 * @param message String to populate `reason' attribute on exception.
 * @throws NSException generated exception from message.
 */
void throwException(NSString *message)
{
    NSException * exception = [NSException exceptionWithName:@"CIF exception"
                                                      reason:message
                                                    userInfo:nil];
    [exception raise];
};

