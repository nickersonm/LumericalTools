#!/bin/bash

# Michael Nickerson 2021


# Variable definitions
export EXECDIR=~/lumerical/tmp/
SUB="~/lumerical/MQ_queue_varfdtd.sh"


# Make sure pueue daemon is started
TOPDIR="$(pwd)"
cd ~ || exit 1
[[ "$( pueue status 2>&1 | grep -c 'Error' )" -eq 0 ]] || pueued -d;
pueue clean


# Process all inputs
for file in "$@"; do {
    cd "$TOPDIR" || exit 1
    
    # Get full path of input and verify existence
    INPUT="$( readlink -f "$file" )"
    cd $EXECDIR || exit 1
    [ -f "$INPUT" ] || {
        echo "Not submitting; '$INPUT' not found, skipping"
        continue
    }
    
    # Check that it's an appropriate file type
    [[ "${INPUT##*.}" == "lsf" ]] || {
        echo "'$INPUT' not a .lsf file, skipping"
        continue
    }
    
    # Submit to local pueue queue if no result file exists
    [ ! -f "${INPUT/.lsf/_varFDTD.mat}" ] && pueue add -g local "$SUB" "$INPUT"
}
done

echo 'Submitted all jobs!'

pueue clean
