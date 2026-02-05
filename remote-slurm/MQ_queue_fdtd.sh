#!/bin/bash

# Michael Nickerson 2022-01
#   Run small Lumerical FDTD job on slurm host
#   Input: single .lsf script to define structure and simulation


## Variable definitions
export EXECDIR=~/lumerical/tmp/

# Local pueue queue definitions
CADQ="local"
ENGQ="fdtd-engine"

# Path definitions
CAD="/sw/cnsi/lumerical/2021R1/bin/fdtd-solutions-app"
ENG="~/lumerical/Qrun_fdtd.sh" # Separate script as it needs to determine memory and node requirements
ANALYSIS="~/lumerical/lumanalysis_template.lsf"
XVFB="~/lumerical/xvnc-run -a"


## Process input
# Get full path of input and verify existence
INPUT="$( readlink -f "$1" )"
BASENAME="$( basename "$INPUT" )"
FSP=${INPUT/.lsf/.fsp}

cd $EXECDIR || exit 1
[[ -f "$INPUT" ]] || {
    echo "'$1' not found, skipping"
    exit 1
}

[[ "${INPUT##*.}" == "lsf" ]] || {
    echo "'$INPUT' not a .lsf file, aborting"
    exit 1
}

# Make temporary script file
TMPLSF="${INPUT/.lsf/_$RANDOM.lsf}"
cp "$INPUT" "$TMPLSF"

# Datafile to pass variables for analysis
TMPLDF=${TMPLSF/.lsf/.ldf}

# Set save location for file and environment to expected output
sed -i -n '/\bsave(/!p;$a\save("'"$FSP"'")\;\nsavedata("'"$TMPLDF"'")\;\n' "$TMPLSF"


## Build temporary self-cleaning files to submit to pueue
SHBUILD=${TMPLSF/.lsf/_build.sh}
SHENGINE=${TMPLSF/.lsf/_engine.sh}
SHANALYZE=${TMPLSF/.lsf/_analyze.sh}


# Script to build .fsp file via CAD
cat > $SHBUILD <<EOT
#!/bin/sh
# Build script into .fsp file via CAD
echo "Processing ${BASENAME} with FDTD..."
$XVFB -s "-screen 0 1600x1200x16" $CAD -hide -run "$TMPLSF" -exit

# Check if .fsp file is produced
[[ -f "$FSP" ]] || {
    echo "Result file $FSP not found, aborting"
    rm "$TMPLSF" "$TMPLDF" # Clean up temporary files
    exit 1
}

# Delete self
rm $SHBUILD
EOT

# Script to run the engine on resulting .fsp
cat > $SHENGINE <<EOT
#!/bin/sh
export NOREFRESH=1  # Skip refresh on engine submission script
# Run engine on resulting .fsp
echo "Running varfdtd-engine on $BASENAME..."
$ENG "$FSP"
echo "Processed $BASENAME"
rm "${FSP/.fsp/_p0.log}"  # Remove engine log file

# Delete self
rm $SHENGINE
EOT

# Script to analyze result with the CAD
cat > $SHANALYZE <<EOT
#!/bin/sh
# Analyze via CAD
echo "Analyzing $BASENAME..."
sed "s#<infile>#${FSP}#;s#<indata>#${TMPLDF}#" $ANALYSIS > "$TMPLSF"    # Reusing previous $TMPLSF
$XVFB -s "-screen 0 1600x1200x16" $CAD -hide -run "$TMPLSF" -exit
rm "$TMPLSF" "$TMPLDF" # Clean up temporary files

echo "Work on $BASENAME complete!"

# Delete self
rm $SHANALYZE
EOT

chmod a+x $SHBUILD $SHENGINE $SHANALYZE


## Execute: submit to pueue queue with chained dependencies
# Build
ID=$( pueue add -g $CADQ "$SHBUILD" | grep -Po '(?<=id )[0-9]+' )

# Add 'after $ID completes' queue for $SHENGINE
ID=$( pueue add -a $ID -g $ENGQ "$SHENGINE" | grep -Po '(?<=id )[0-9]+' )

# Add 'after $ID completes' queue for $SHANALYZE
pueue add -a $ID -g $CADQ "$SHANALYZE"

