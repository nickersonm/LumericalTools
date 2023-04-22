#!/bin/bash
# Michael Nickerson 2022-01-04
#   Updated 2022-07-27
#   Run small Lumerical FDTD job on slurm-host, to be used with remote dispatch
#   Input: fsp file with FDTD simulation
#   Set REFRESH=1 to refresh fsp file

#set -x

## Variable definitions
EXECDIR="$(readlink -f ~/lumerical/tmp/)"

# Queue commands
THREADS=16  # CPUs per node (20 hyperthreaded cores per node on slurm-host, 32 threads per FDTD license)
MAXNODES=4  # Does not scale so well to large numbers
NODES=$MAXNODES
QRUN="/usr/bin/srun --exclude=node19 --chdir=""$EXECDIR"" --mpi=pmi2 --nodes=$MAXNODES --cpus-per-task=$THREADS --time=10:00:00 --mem=12G -p batch --job-name=fdtdEng"
# Unfortunately on 'slurm-host', the nodes can't run the CAD applications without core dumping
#   Unable to determine cause, even with extensive Xvfb testing
QCAD="nice -n 15"

# Path definitions
CAD="/sw/cnsi/lumerical-2021R1/bin/fdtd-solutions-app"
ENG="/sw/cnsi/lumerical-2021R1/bin/fdtd-engine-mpich2nem"
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

[[ "${INPUT##*.}" == "fsp" ]] || {
    echo "'$INPUT' not a .fsp file, aborting"
    exit 1
}

# Sleep to avoid race conditions in batch submissions
sleep $(($RANDOM % 5))

[[ "$REFRESH" -eq 1 ]] && {
    # Make temporary refresh script
    TMPSCRIPT="${INPUT/.fsp/_refresh_$RANDOM.lsf}"
    sed "s#<infile>#${INPUT}#" "$LSFREFRESH" > "$TMPSCRIPT"

    # Load and refresh file with CAD to avoid cross-version bugs
    printf "Refreshing %s to avoid cross-version bugs..." $BASENAME
    $QCAD $XVFB $CAD -nw -run "$TMPSCRIPT" -exit
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
#   ~180 GB on slurm-host 'batch'
#   1.4 TB on slurm-host 'largemem'
MEM=$( grep -Po '(?<=memory=)\d*' <<< "$MR" )
MEM=$(( (MEM * 120 / 100)/1024 + 4 ))   # Reasonable minimum and overhead
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
GRID=$( grep -Po '(?<=gridpoints=)\d*' <<< "$MR" )
[[ $GRID -lt 0 ]] && GRID=2147483647    # Signed 32-bit overflow

# Estimated total time required from Lumerical templates, roughly calibrated on slurm-host
TIME=$(( GRID * TIME / 75 / 3 / 1000000 / 60 ))    # In minutes
echo "  Expected $TIME minutes CPU time"

[[ $NODES -eq 2 ]] && {         # If not defined otherwise in memory section
    NODES=$(( TIME/60 + 1 ))    # Rough estimate of nodes required; ~60 minute jobs
}
NODES=$(( NODES < MAXNODES ? NODES : MAXNODES ))  # Cap requested nodes
echo "  Using $NODES nodes, expected $((TIME/NODES)) minutes real execution time"

TIME=$((TIME / NODES / 60 + 1))     # Expected execution hours
[[ $TIME -gt 6 ]] && {
    TIME=$((TIME * 3/2))        # Request more time
    echo "  Requesting $TIME hours of job time"
}
[[ $TIME -lt 10 ]] && TIME=10   # Minimum request

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
rm "${INPUT/.fsp/_p0.log}"  # Remove engine log file

echo "Work on $BASENAME complete!"
