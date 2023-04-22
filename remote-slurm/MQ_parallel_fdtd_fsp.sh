#!/bin/bash

# Michael Nickerson 2021


# Variable definitions
export EXECDIR=~/lumerical/tmp/
FDTDSUB="~/lumerical/Qrun_fdtd.sh"


# Helper functions
function relPath() {
    cd $EXECDIR || exit 1
    perl -e 'use File::Spec; print File::Spec->abs2rel(@ARGV) . "\n"' "$1" ./
}


# Make sure pueue daemon is started
[[ "$( pueue status 2>&1 | grep -c 'Error' )" -eq 0 ]] || pueued -d;
pueue clean


# Process all inputs
TOPDIR="$(pwd)"
for file in "$@"; do {
    cd $TOPDIR || exit 1
    
    # Get full path of input (including ~/lumerical symlink present on both clusters) and verify existence
    INPUT=${EXECDIR}/$( relPath "$( readlink -f $file )" )
    cd $EXECDIR || exit 1
    [ -f "$INPUT" ] || {
        echo "'$1' not found, skipping"
        continue
    }

    # Check that it's an appropriate file type
    [[ "${INPUT##*.}" == "fsp" ]] || {
        echo "'$INPUT' not a .fsp file, skipping"
        continue;
    }
    
    # Submit to local pueue queue for FDTD
    pueue add -g 'fdtd-engine' "$FDTDSUB" "$INPUT"
}
done

echo 'Submitted all jobs!'

pueue clean &>/dev/null
