#!/bin/bash
shopt -s expand_aliases
set +x
#DPBmodule load python

function log() {
  dt=$(date --utc +"%Y-%m-%d %H:%M:%S,%3N [wrapper-wrapper]")
  echo "$dt $@"
}

function err() {
  dt=$(date --utc +"%Y-%m-%d %H:%M:%S,%3N [wrapper-wrapper]")
  echo "$dt $@" >&2
}

function trap_handler() {
  if [[ -n "${pilotpid}" ]]; then
    log "WARNING: trap caught signal:$1, signalling pilot PID: $pilotpid"
    err "WARNING: trap caught signal:$1, signalling pilot PID: $pilotpid"
    #DPBkill -s $1 $pilotpid                                                                                                                                                                                                                
    #DPBwait                                                                                                                                                                                                                                
  else
    log "WARNING: trap Caught signal:$1 prio to getting pilot PID:"
  fi
}

trap 'trap_handler 2' SIGINT
trap 'trap_handler 3' SIGQUIT
trap 'trap_handler 7' SIGBUS
trap 'trap_handler 10' SIGUSR1
trap 'trap_handler 11' SIGSEGV
trap 'trap_handler 12' SIGUSR2
trap 'trap_handler 15' SIGTERM
trap 'trap_handler 18' SIGCONT
trap 'trap_handler 24' SIGXCPU

export TZ=UTC0

echo "[$(date -u "+%m-%d-%y %H:%M:%S %Z")] trap_handler done"

echo "[$(date -u "+%m-%d-%y %H:%M:%S %Z")] Start CVMFSExec functions"

#====== CVMFSExec functions ===========================================
clean_cvmfsexec() {
    echo "[$SECONDS] Cleaning up stale FUSE mounts from previous jobs"
    for repo in $CVMFS_REPOS; do
        /usr/bin/fusermount -u "${JOBTMP}/cvmfsexec/dist/cvmfs/${repo}" >& /dev/null
    done
    echo "[$SECONDS] Cleaning up stale files"
    rm -rf "$JOBTMP"
}

check_cvmfsexec() {
    ready=0
    for repo in $CVMFS_REPOS; do
        if ! df -h | grep -q "$repo"; then
            ready=1
            break
        fi
    done
    return $ready
}

setup_cvmfsexec() {
    # Setup CVMFSExec
    echo "[$SECONDS] Installing CVMFSExec $cvmfsexec_home"
    cat "$cvmfsexec_home/latestVersion"
    cat "$cvmfsexec_home/cvmfsexecVersion.sh"
    "$cvmfsexec_home/install" -z -s -p "$JOBTMP" -c "$cvmfsexec_home/default.local"
    echo "[$SECONDS] Mounting CVMFS"
    sh "$JOBTMP/cvmfsexec/mount.sh"
    echo "[$SECONDS] Mounting CVMFS"
    "$JOBTMP/cvmfsexec" $CVMFS_REPOS -- /bin/bash
}

setup_cvmfsexec_exe() {
    # Setup CVMFSExec
    echo "[$SECONDS] Making tmpdir for CVMFSExec"
    mkdir -p "$2"
    echo "[$SECONDS] cp over self extract cvmfsExec $1 to $2"
    cp -v "$1" "$2/$(basename "$1")"
    chmod +x "$2/$(basename "$1")"
}

wait_for_cvmfsexec() {
    max_iterations=5
    i=0
    while true; do
        i=$((i+1))
        if [ $i -eq $max_iterations ]; then
            echo "[$SECONDS] Exhausted waiting for CVMFSExec.. giving up"
            break
        fi
        if check_cvmfsexec; then
            echo "[$SECONDS] CVMFSExec is ready! Continuing"
            break
        else
            echo "[$SECONDS] Not yet ready. Sleeping 120s"
            sleep 120
        fi
    done
}

#######################################################################
# main                                                                #
#######################################################################
echo "[$(date -u "+%m-%d-%y %H:%M:%S %Z")] Start main"
PANDA_QUEUE=$1
HARVESTER_ACCESS_POINT=$2

# setup cvmfsexec
CVMFS_REPOS="config-osg.opensciencegrid.org atlas.cern.ch atlas-condb.cern.ch atlas-nightlies.cern.ch sft.cern.ch sft-nightlies.cern.ch unpacked.cern.ch"
run_container=false
echo "[$(date -u "+%m-%d-%y %H:%M:%S %Z")] Setting up CVMFSExec"

if ! check_cvmfsexec; then
  run_container=true
  echo "[$SECONDS] CVMFS is not available. Will set it up using CVMFSExec"
  echo "[$SECONDS] Setting up CVMFSExec"

  echo "[$SECONDS] 1. Trying to use CVMFSExec executable from $cvmfsexecExtra...."
  if [[ ! -e "$cvmfsexecExtra" ]]; then
    echo "[$SECONDS] WARNING: cvmfsexecExtra $cvmfsexecExtra does not exist."
    echo "[$SECONDS] 2. Assuming CVMFS will be mounted inside of container via CVMFSExec."
  else
    echo "[$SECONDS] found CVMFSExec executable $cvmfsexecExtra. Will use it to setup CVMFS in the container."

    # UNIQUE_ID="${PBS_JOBID}_${PBS_ARRAY_INDEX:-0}_${PBS_TASKNUM:-0}"
    # SAFE_ID=$(echo "$UNIQUE_ID" | tr -cd '[:alnum:]_-')
    JOBTMP="$localScratchBase/$PBS_JOBID/${PBS_TASKNUM:-0}"
    echo "[$SECONDS] CVMFSExec executable will be extracted to $JOBTMP"
    setup_cvmfsexec_exe "$cvmfsexecExtra" "$JOBTMP"

    echo "[$SECONDS] Set CVMFS_BASE=$JOBTMP/.cvmfsexec"
    export CVMFS_BASE="$JOBTMP/.cvmfsexec/dist/cvmfs"
  fi
fi

# create unique Harvester workdirectory for each pilot
HARVESTER_WORKDIR="$HARVESTER_ACCESS_POINT/${PBS_JOBID}/${PBS_TASKNUM:-0}"

echo  [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "create new working directory (if needed) - "$HARVESTER_WORKDIR
if [ ! -e $HARVESTER_WORKDIR ] ; then mkdir -pv $HARVESTER_WORKDIR ; fi
cd $HARVESTER_WORKDIR
echo  [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Now in working directory - "${PWD}
echo

# create $MACHINEFEATURES/shutdowntime file with the job's expected end time.
# PBS has no direct env var for this (unlike SLURM_JOB_END_TIME), so derive it
# from the requested walltime added to the current time.
export MACHINEFEATURES=$HARVESTER_WORKDIR
PBS_WALLTIME=$(qstat -f "$PBS_JOBID" 2>/dev/null | awk -F'= ' '/Resource_List.walltime/{gsub(/[ \t\r]/,"",$2); print $2}')
if [[ "$PBS_WALLTIME" =~ ^([0-9]+):([0-9]+):([0-9]+)$ ]]; then
  PBS_WALLTIME_SECONDS=$((10#${BASH_REMATCH[1]} * 3600 + 10#${BASH_REMATCH[2]} * 60 + 10#${BASH_REMATCH[3]}))
  PBS_JOB_END_TIME=$(( $(date +%s) + PBS_WALLTIME_SECONDS ))
else
  echo "[$SECONDS] WARNING: could not determine PBS walltime for job $PBS_JOBID"
  PBS_JOB_END_TIME=""
fi
echo $PBS_JOB_END_TIME > $MACHINEFEATURES/shutdowntime

echo  [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "value of  \$MACHINEFEATURES = " ${MACHINEFEATURES}
echo  [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "ls -l  \$MACHINEFEATURES/shutdowntime = " $(ls -l $MACHINEFEATURES/shutdowntime)
echo  [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Content of the \$MACHINEFEATURES/shutdowntime file " $(cat $MACHINEFEATURES/shutdowntime)

if [ -z $ATLAS_SW_BASE ]; then
    export ATLAS_SW_BASE=/cvmfs
fi
# Credentials
# export X509_USER_PROXY=$HARVESTER_DIR/globus/lincolnb/harvester-vomsproxy-usatlas

# export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
if [ -z $ATLAS_LOCAL_ROOT_BASE ]; then
    export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
fi

echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] setup_ALRB
source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh --quiet
echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] finished_setup_ALRB


module use /soft/modulefiles
module load spack-pe-base
module load apptainer

  export HTTP_PROXY=http://proxy.alcf.anl.gov:3128
  export HTTPS_PROXY=http://proxy.alcf.anl.gov:3128
  export http_proxy=http://proxy.alcf.anl.gov:3128
  export https_proxy=http://proxy.alcf.anl.gov:3128

  export FRONTIER_SERVER="(serverurl=http://v4fa.cern.ch/atlr)(serverurl=http://v4fb.cern.ch/atlr)(proxyurl=http://proxy.alcf.anl.gov:3128)"

  IMAGE_AREA=/lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/harvester/image
  # export ATLAS_LOCAL_ROOT_BASE=/lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/harvester/alrb/ATLASLocalRootBase/
  # source "${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh"
  echo "[$SECONDS] Change directory to $HARVESTER_WORKDIR"
  cd "$HARVESTER_WORKDIR"

  if [ -n "$Local_Pilot" ]; then
    echo "[$SECONDS] Local_Pilot is set, using local pilot at $Local_Pilot"
    pilot_py="$Local_Pilot"
  else
    pilot_tar_file="$ATLAS_SW_BASE/atlas.cern.ch/repo/sw/PandaPilot/tar/pilot3.tar.gz"
    echo "[$SECONDS] Local_Pilot is not set, fetching pilot from $pilot_tar_file"
    mkdir -p "$HARVESTER_WORKDIR/pilot"
    tar -xzf "$pilot_tar_file" -C "$HARVESTER_WORKDIR/pilot"
    pilot_py="$HARVESTER_WORKDIR/pilot/pilot3/pilot.py"
  fi

  if [ -z "$prodsourcelabel" ]; then
    prodsourcelabel=managed
  fi

  echo "[$SECONDS] Done with setup, starting pilot wrapper"
  cmd="python3 $pilot_py -q \"$PANDA_QUEUE\" -i PR -j $prodsourcelabel -w generic --url https://pandaserver.cern.ch --pilot-user ATLAS --allow-same-user=False --getjobrequests=150 --notokenrenewal --cleanup True --noworkerpilotstatusupdate -x 50 --debug --cvmfsbase $CVMFS_BASE --cleanup False"

  # run.sh mounts CVMFS via cvmfsexec, runs the pilot inside that mount, then
  # stops cvmfsexec and cleans up its installation in $JOBTMP on exit.
  cat <<EOF3 > "$HARVESTER_WORKDIR/run.sh"
#!/bin/bash
jobtmp="$JOBTMP"
export CVMFS_REPOS="$CVMFS_REPOS"

mkdir -p "\$jobtmp"
cp "$cvmfsexecExtra" "\$jobtmp/cvmfsexec"
chmod +x "\$jobtmp/cvmfsexec"

stop_cvmfsexec() {
  echo "[run.sh] Stopping CVMFSExec and cleaning up \$jobtmp"
  for repo in \$CVMFS_REPOS; do
    fusermount -u "\$jobtmp/.cvmfsexec/dist/cvmfs/\$repo" >/dev/null 2>&1
  done
  rm -rf "\$jobtmp"
}
trap stop_cvmfsexec EXIT

"\$jobtmp/cvmfsexec" \$CVMFS_REPOS -- $cmd
EOF3
  chmod +x "$HARVESTER_WORKDIR/run.sh"

  echo "Running in el9 container:"
  echo "apptainer exec -B /lus/eagle/projects/ATLAS_workflow_ALCF/usatlas -B /home  /lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/harvester/image/atlas-grid-almalinux9.sif $HARVESTER_WORKDIR/run.sh"
  apptainer exec -B /lus/eagle/projects/ATLAS_workflow_ALCF/usatlas -B /home /lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/harvester/image/atlas-grid-almalinux9.sif "$HARVESTER_WORKDIR/run.sh"

