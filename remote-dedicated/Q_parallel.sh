#!/bin/bash

# Michael Nickerson 2021


# Variable definitions
SOLV=$1
shift
[[ -z "$SOLV" ]] && {
    echo "No solver specified!"
    exit 1
}
EXECDIR=~/lumerical/tmp/
RUN="~/lumerical/Q_selected.sh"


# Helper functions
function relPath() {
    cd $EXECDIR || exit 1
    perl -e 'use File::Spec; print File::Spec->abs2rel(@ARGV) . "\n"' "$1" ./
}


# Process all inputs
TOPDIR="$(pwd)"
for file in "$@"; do {
    cd "$TOPDIR" || exit 1
    
    # Get full path of input (including ~/lumerical symlink present on both clusters) and verify existence
    INPUT=${EXECDIR}/$( relPath "$( readlink -f "$file" )" )
    cd $EXECDIR || exit 1
    [ -f "$INPUT" ] || {
        echo "'$1' not found, skipping"
        continue
    }

    # Check that it's an appropriate file type
    [[ "${INPUT##*.}" == "lsf" ]] || {
        echo "'$INPUT' not a .lsf file, skipping"
        continue;
    }
    
    # Check if output exists; skip if so
    [[ -n $(find "$(dirname "$INPUT")" -iname "$(basename "${INPUT/.lsf/_$SOLV.mat}")") ]] || {
        # Submit for processing
        "$RUN" "$SOLV" "$INPUT"
    }
}
done

echo 'Submitted all jobs!'
