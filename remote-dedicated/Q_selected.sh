#!/bin/bash

# Michael Nickerson 2022-10
#   Run small Lumerical job
#   Input: single .lsf script to define structure and simulation


## Variable definitions
SOLV=$1
[[ -z "$SOLV" ]] && {
    echo "No solver specified!"
    exit 1
}

BUILDONLY="${BUILDONLY:=0}"
PREBUILD="${PREBUILD:=0}"
POSTBUILD="${POSTBUILD:=0}"

EXECDIR=~/lumerical/tmp/

# Local pueue queue definitions
CADQ="cad"
ENGQ="engine"

# Path definitions
ANALYSIS="~/lumerical/lumanalysis_template.lsf"
NICE="nice -n 15"
XVNC="~/lumerical/xvnc-run -a"


## Process input
# Get full path of input and verify existence
INPUT="$( readlink -f "$2" )"
BASENAME="$( basename "$INPUT" )"

cd $EXECDIR || exit 1
[[ -f "$INPUT" ]] || {
    echo "'$2' not found, skipping"
    exit 1
}

[[ "${INPUT##*.}" == "lsf" ]] || {
    echo "'$INPUT' not a .lsf file, aborting"
    exit 1
}

# Find solver
case $SOLV in
    fde | mode)
        CAD="/opt/lumerical/v222/bin/mode-solutions-app -use-solve"
        ENG="/opt/lumerical/v222/bin/fd-engine -t 4"
        SOL=${INPUT/.lsf/.lms}
        ;;
    eme)
        CAD="/opt/lumerical/v222/bin/mode-solutions-app"
        ENG="/opt/lumerical/v222/bin/eme-engine-mpich2nem -n 1 -t 4"
        SOL=${INPUT/.lsf/.lms}
        ;;
    fdtd)
        CAD="/opt/lumerical/v222/bin/fdtd-solutions-app"
        ENG="/opt/lumerical/v222/bin/fdtd-engine-mpich2nem -n 1 -t 16"
        SOL=${INPUT/.lsf/.fsp}
        ENGQ="fdtd-engine"
        ;;
    varfdtd)
        CAD="/opt/lumerical/v222/bin/mode-solutions-app -use-solve"
        ENG="/opt/lumerical/v222/bin/varfdtd-engine-mpich2nem -t 4"
        SOL=${INPUT/.lsf/.lms}
        ;;
    device | charge)
        CAD="/opt/lumerical/v222/bin/device-app -use-solve"
        ENG="/opt/lumerical/v222/bin/device-engine-mpich2nem -t 4"
        SOL=${INPUT/.lsf/.ldev}
        ;;
    *)
        echo "Unknown solver $SOLV"
        exit 0
        ;;
esac


# Make temporary script file
TMPSCRIPT="${INPUT/.lsf/_working_${SOLV}.lsf}"
cp "$INPUT" "$TMPSCRIPT"

# Datafile to pass variables for analysis
TMPLDF=${TMPSCRIPT/.lsf/.ldf}

# Set save location for file and environment to expected output
sed -i -n '/\bsave(/!p;$a\save("'"$SOL"'")\;\nsavedata("'"$TMPLDF"'")\;\n' "$TMPSCRIPT"


## Build temporary self-cleaning files to submit to pueue
SHBUILD=${TMPSCRIPT/.lsf/_build.sh}
SHENGINE=${TMPSCRIPT/.lsf/_engine.sh}
SHANALYZE=${TMPSCRIPT/.lsf/_analyze.sh}


[[ $POSTBUILD -eq 1 ]] || {
# Script to build solver file via CAD
# $XVNC -s "-screen 0 1600x1200x16" $CAD -nw -run "$TMPSCRIPT" -exit -trust-script
cat > "$SHBUILD" <<EOT
#!/bin/bash
# Build script into solver file via CAD
echo "Processing ${BASENAME}..."
$NICE $XVNC $CAD -nw -run "$TMPSCRIPT" -exit -trust-script

# Check if solver file is produced
[[ -f "$SOL" ]] || {
    echo "Result file $SOL not found, aborting"
    rm "$TMPSCRIPT" "$TMPLDF" # Clean up temporary files
    exit 1
}

# Delete self
rm "$SHBUILD"
EOT
[[ $BUILDONLY -eq 1 ]] && echo "rm \"$TMPSCRIPT\" \"$TMPLDF\"" >> "$SHBUILD"
[[ $PREBUILD -eq 1 ]] && echo "rm \"$TMPSCRIPT\"" >> "$SHBUILD"

chmod a+x "$SHBUILD"
}


[[ $BUILDONLY -eq 1 ]] || [[ $PREBUILD -eq 1 ]] || {
[[ $POSTBUILD -eq 1 ]] || {
# Script to run the engine on resulting solver
cat > "$SHENGINE" <<EOT
#!/bin/bash
# Run engine on resulting solver
echo "Running engine on $SOL..."
$NICE $ENG "$SOL"
echo "Processed $SOL"
rm "${SOL%.*}_p0.log"  # Remove engine log file

# Delete self
rm "$SHENGINE"
EOT
chmod a+x "$SHENGINE"
}

# Script to analyze result with the CAD
# $XVNC -s "-screen 0 1600x1200x16" $CAD -nw -run "$TMPSCRIPT" -exit -trust-script
cat > "$SHANALYZE" <<EOT
#!/bin/bash
# Analyze via CAD
echo "Analyzing $SOL..."
sed "s#<infile>#${SOL}#;s#<indata>#${TMPLDF}#" $ANALYSIS > "$TMPSCRIPT"    # Reusing previous $TMPSCRIPT
$NICE $XVNC $CAD -nw -run "$TMPSCRIPT" -exit -trust-script
rm "$TMPSCRIPT" "$TMPLDF" # Clean up temporary files

echo "Work on $BASENAME complete!"

# Delete self
rm "$SHANALYZE"
EOT

chmod a+x "$SHANALYZE"
}



# Make sure pueue daemon is started
[[ "$( pueue status 2>&1 | grep -c 'Error' )" -eq 0 ]] || pueued -d;
pueue clean &>/dev/null

## Execute: submit to pueue queue with chained dependencies
[[ $POSTBUILD -eq 1 ]] || {
# Build
ID=$( pueue add -g $CADQ "$SHBUILD" | grep -Po '(?<=id )[0-9]+' )
# echo pueue add -g $CADQ "$SHBUILD"
}

[[ $BUILDONLY -eq 1 ]] || [[ $PREBUILD -eq 1 ]] || [[ $POSTBUILD -eq 1 ]] || {
    # Add 'after $ID completes' queue for $SHENGINE
    ID=$( pueue add -a $ID -g $ENGQ "$SHENGINE" | grep -Po '(?<=id )[0-9]+' )

    # Add 'after $ID completes' queue for $SHANALYZE
    pueue add -a $ID -g $CADQ "$SHANALYZE"
}
[[ $POSTBUILD -eq 1 ]] && pueue add -g $CADQ "$SHANALYZE"
