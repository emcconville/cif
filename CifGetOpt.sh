#!/bin/sh
#
#  Copyright (c) 2015 Eric McConville.
#  https://github.com/emcconville/cif

__CifGetOpt__() {
 local C=${COMP_WORDS[0]}
 local F
 local P=${COMP_WORDS[COMP_CWORD]}
 local R=()
 local W
 case "$P" in
   CI*)
    W=$(${C} list)
    COMPREPLY=($(compgen -W "$W" $P))
    ;;
   -*)
    F=${COMP_WORDS[1]}
    W=$(${C} list $F|grep -e '^ -'|cut -d ' ' -f 2)
    R=($( compgen -W "$W" -- $P))
    ;;
 esac
 COMPREPLY=R
 return 0;
}

complete -F __CifGetOpt__ -o default cif
