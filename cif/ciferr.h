//
//  ciferr.h
//  cif
//
//  Created by Eric McConville on 6/29/15.
//  Copyright (c) 2015 Eric McConville. All rights reserved.
//

#ifndef __cif__ciferr__
#define __cif__ciferr__

#import <Foundation/Foundation.h>

#pragma mark Exceptions

/**
 * @brief Helper function to allocate & throw exceptions from given string.
 * @param message String to populate `reason' attribute on exception.
 * @throws NSException generated exception from message.
 */
void throwException(NSString *message);

#endif /* defined(__cif__ciferr__) */
