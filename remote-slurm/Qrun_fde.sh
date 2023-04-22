#!/bin/bash

# Michael Nickerson 2022-01-03
#   Updated 2022-07-27
#   Run small Lumerical FDE job on slurm host, to be used with remote dispatch
#   Input: lms file with FDE simulation
#   Set REFRESH=1 to refresh lms file


## Variable definitions
EXECDIR="$(readlink -f ~/lumerical/tmp/)"

# Queue commands
THREADS=32  # CPUs per node (20 hyperthreaded cores per node on slurm-host, 32 threads per solver license)
NODES=1  # Does not distribute
QRUN="/usr/bin/srun --exclude=node19 --chdir=""$EXECDIR"" --mpi=pmi2 --nodes=$NODES --cpus-per-task=$THREADS --time=10:00:00 --mem=12G -p batch --job-name=fdeEng"
# Unfortunately on 'slurm-host', the nodes can't run the CAD applications without core dumping
#   Unable to determine cause, even with extensive Xvfb testing
QCAD="nice -n 15"

# Path definitions
CAD="/sw/cnsi/lumerical-2021R1/bin/mode-solutions-app"
ENG="/sw/cnsi/lumerical-2021R1/bin/fd-engine"
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

[[ "${INPUT##*.}" == "lms" ]] || {
    echo "'$INPUT' not a .lms file, aborting"
    exit 1
}

# Sleep to avoid race conditions in batch submissions
sleep $(($RANDOM % 5))

[[ "$REFRESH" -eq 1 ]] && {
    # Make temporary refresh script
    TMPSCRIPT="${INPUT/.lms/_refresh_$RANDOM.lsf}"
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
rm "${INPUT/.lms/_p0.log}"  # Remove engine log file

echo "Work on $BASENAME complete!"
