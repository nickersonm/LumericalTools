#!/bin/bash

# Michael Nickerson 2022-01-03
#   Updated 2022-07-27
#   Run small Lumerical varfdtd job on slurm host, to be used with remote dispatch
#   Input: lms file with varfdtd simulation
#   Set REFRESH=1 to refresh lms file


## Variable definitions
EXECDIR="$(readlink -f ~/lumerical/tmp/)"

# Queue commands
THREADS=16  # CPUs per node (20 hyperthreaded cores per node on slurm-host, 32 threads per solver license)
MAXNODES=4  # Does not scale so well to large numbers
NODES=$MAXNODES
QRUN="/usr/bin/srun --exclude=node19 --chdir=""$EXECDIR"" --mpi=pmi2 --nodes=$MAXNODES --cpus-per-task=$THREADS --time=10:00:00 --mem=12G -p batch --job-name=varfdtdEng"
# Unfortunately on 'slurm-host', the nodes can't run the CAD applications without core dumping
#   Unable to determine cause, even with extensive Xvfb testing
QCAD="nice -n 15"

# Path definitions
CAD="/sw/cnsi/lumerical-2021R1/bin/mode-solutions-app"
ENG="/sw/cnsi/lumerical-2021R1/bin/varfdtd-engine-mpich2nem"
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
    $QCAD $XVFB $CAD -hide -run "$TMPSCRIPT" -exit
    rm "$TMPSCRIPT"
    printf " done\n"
}


## Check memory and time requirements to decide submission options
# Get memory and time requirements
printf "Checking memory and CPU requirements..."
MR="$($ENG -mr "$INPUT")"
printf "\n"

# Check memory
# Available:
#   4x126GB, >10x64GB, >10x48GB on slurm-host 'batch'
#   768GB on slurm-host 'largemem'
MEM=$( grep -Po '(?<=memory=)\d*' <<< "$MR" )
MEM=$(( (MEM * 200 / 100)/1024 + 4 ))   # Reasonable minimum and overhead
echo "  Need ~${MEM}GB memory"

if [[ $MEM -gt 1300 ]]; then
    echo "  Error, memory requirements (~${MEM}GB) not satisfiable!"
    exit 1
elif [[ $MEM -gt 180 ]]; then
    echo "    Using 'largemem' queue on slurm-host"
    QRUN=${QRUN//batch/largemem}  # Different queue
    NODES=2 # Maximum 'largemem' nodes
fi

# Check time
TIME=$( grep -Po '(?<=time_steps=)\d*' <<< "$MR" )
[[ $TIME -gt 0 ]] || TIME=500000	# On error, use typical value
GRID=$( grep -Po '(?<=gridpoints=)\d*' <<< "$MR" )
[[ $GRID -lt 0 ]] && GRID=2147483647    # Signed 32-bit overflow
[[ $GRIS -eq 0 ]] && GRID=10000000	# On error, use typical value

# Estimated total time required from Lumerical templates, roughly calibrated on slurm-host
TIME=$(( GRID * TIME / 75 / 1000000 / 60 ))    # In minutes
echo "  Expected $TIME minutes CPU time"

[[ $NODES -eq 2 ]] && {         # If not defined otherwise in memory section
    NODES=$(( TIME/15 + 1 ))    # Rough estimate of nodes required; ~15 minute jobs
}
NODES=$(( NODES < MAXNODES ? NODES : MAXNODES ))  # Cap requested nodes
echo "  Using $NODES nodes, expected $((TIME/NODES)) minutes real execution time"

TIME=$((TIME/NODES/60 + 1))     # Expected execution hours
[[ $TIME -gt 5 ]] && {
    TIME=$((TIME * 3/2))        # Request more time
    echo "  Requesting $TIME hours of job time"
}
[[ $TIME -lt 5 ]] && TIME=5   # Minimum request

# Update queue command from previously calculated memory, nodes, and time
QRUN=${QRUN//mem=12/mem=$MEM}
QRUN=${QRUN//nodes=$MAXNODES/nodes=$NODES}
QRUN=${QRUN//time=10/time=$TIME}


## Submit job interactively
echo "Running $(basename $ENG) on $BASENAME..."
$QRUN $ENG -t $THREADS -n $NODES \"$INPUT\" || {
    echo "Error processing $BASENAME, aborting"
    exit 1
}
echo "Processed $BASENAME"
rm "${INPUT/.lms/_p0.log}"  # Remove engine log file

echo "Work on $BASENAME complete!"
