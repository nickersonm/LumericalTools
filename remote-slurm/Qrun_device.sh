#!/bin/bash

# Michael Nickerson 2022-01-04
#   Updated 2022-07-27
#   Run small Lumerical EME job on slurm host, to be used with remote dispatch
#   Input: ldev file with EME simulation
#   Set REFRESH=1 to refresh ldev


## Variable definitions
export EXECDIR=~/lumerical/tmp/

# Queue commands
THREADS=12  # Default
NODES=2     # Default; cannot get expected runtime in advance
# node52 seems to have trouble 2022-09-13
QRUN="/usr/bin/srun --exclude=node52 --mpi=pmi2 --nodes=$NODES --cpus-per-task=$THREADS --time=10:00:00 --mem=12G -p batch --job-name=deviceEng"
# Unfortunately on 'slurm-host', the nodes can't run the CAD applications without core dumping
#   Unable to determine cause, even with extensive Xvfb testing
QCAD="nice -n 15"

# Path definitions
CAD="/sw/cnsi/lumerical/2021R1/bin/device-app"
ENG="/sw/cnsi/lumerical/2021R1/bin/device-engine-mpich2nem"
LSFREFRESH="~/lumerical/refresh.lsf"
XVFB="~/lumerical/xvnc-run -a"


## Process input
# Get full path of input and verify existence
INPUT="$( readlink -f $1 )"
BASENAME="$( basename "$INPUT" )"

cd $EXECDIR || exit 1
[[ -f "$INPUT" ]] || {
    echo "'$1' not found, skipping"
    exit 1
}

[[ "${INPUT##*.}" == "ldev" ]] || {
    echo "'$INPUT' not a .ldev file, aborting"
    exit 1
}

# Sleep to avoid race conditions in batch submissions
sleep $(($RANDOM % 3))

[[ "$REFRESH" -eq 1 ]] && {
    # Make temporary refresh script
    TMPSCRIPT="${INPUT/.ldev/_refresh_$RANDOM.lsf}"
    sed "s#<infile>#${INPUT}#" "$LSFREFRESH" > "$TMPSCRIPT"

    # Load and refresh file with CAD to avoid cross-version bugs
    printf "Refreshing %s to avoid cross-version bugs..." $BASENAME
    $QCAD $XVFB $CAD -nw -run "$TMPSCRIPT" -exit
    rm "$TMPSCRIPT"
    printf " done\n"
}


## Submit job interactively
echo "Running $(basename $ENG) on $BASENAME..."
$QRUN $ENG -t $THREADS \"$INPUT\" || {
    echo "Error processing $BASENAME, aborting"
    exit 1
}
echo "Processed $BASENAME"
rm "${INPUT/.ldev/_p0.log}"  # Remove engine log file

echo "Work on $BASENAME complete!"
