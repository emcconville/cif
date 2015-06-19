#!/bin/sh

#  CifGetOpt.sh
#  cif
#
#  Created by Eric McConville on 6/18/15.
#  Copyright (c) 2015 Eric McConville. All rights reserved.

__CifGetOpt__()
{
    local phrase
    local __cif
    COMPREPLY=()
    phrase=${COMP_WORDS[COMP_CWORD]}
    __cif=${COMP_WORDS[0]}

    case "$phrase" in
        CI*)
            local words
            words=$( ${__cif} list )
            COMPREPLY=( $( compgen -W "$words" $phrase) )
        ;;
        -*)
            local filter
            local words
            filter=${COMP_WORDS[1]}
            words=$( ${__cif} list $filter | grep -e '^ -' | cut -d ' ' -f 2)
            COMPREPLY=( $( compgen -W "$words --" -- $phrase) )
        ;;
    esac
    return 0;
}
