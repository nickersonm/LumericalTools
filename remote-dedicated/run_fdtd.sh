#!/bin/bash

# Michael Nickerson 2022-07-27
#   Run small Lumerical FDTD job on a Linux machine, to be used with remote dispatch
#   Input: fsp file with FDTD simulation
#   Set REFRESH=1 to refresh/regenerate fsp file before execution; useful when working with disparate versions


## Variable definitions
export EXECDIR=~/lumerical/tmp/

# Performance and path definitions
THREADS=16  # Default
CAD="/opt/lumerical/v222/bin/fdtd-solutions-app"
ENG="/opt/lumerical/v222/bin/fdtd-engine-mpich2nem"
LSFREFRESH="~/lumerical/refresh.lsf"
NICE="nice -n 15"
XVNC="~/lumerical/xvnc-run -a"


## Process input
# Get full path of input and verify existence
INPUT="$( readlink -f "$1" )"
BASENAME="$( basename "$INPUT" )"

cd $EXECDIR || exit 1
[[ -f "$INPUT" ]] || {
  echo "'$1' not found, skipping"
  exit 1
}

[[ "${INPUT##*.}" == "fsp" ]] || {
  echo "'$INPUT' not a .fsp file, aborting"
  exit 1
}

# Possibly refresh/regenerate the fsp file
[[ "$REFRESH" -eq 1 ]] && {
  # Make temporary refresh script
  TMPSCRIPT="${INPUT/.fsp/_refresh_$RANDOM.lsf}"
  sed "s#<infile>#${INPUT}#" "$LSFREFRESH" > "$TMPSCRIPT"
  
  # Load and refresh file with CAD to avoid cross-version bugs
  printf "Refreshing %s to avoid cross-version bugs..." $BASENAME
  $NICE $XVNC $CAD -nw -run "$TMPSCRIPT" -exit
  rm "$TMPSCRIPT"
  printf " done\n"
}


## Run job
echo "Running $(basename $ENG) on $BASENAME..."
$NICE $ENG -t $THREADS \"$INPUT\" || {
  echo "Error processing $BASENAME, aborting"
  exit 1
}
echo "Processed $BASENAME"
rm "${INPUT/.fsp/_p0.log}"  # Remove engine log file

echo "Work on $BASENAME complete!"
