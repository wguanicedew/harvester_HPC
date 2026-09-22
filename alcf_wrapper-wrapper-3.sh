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
    cp -v "$1" "$2/cvmfsexec"
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
scheduler=${3:-PBS}

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

    if [[ "$scheduler" =~ "SLURM" ]]; then
      JOBTMP="$localScratchBase/$SLURM_LOCALID"
    elif [[ "$scheduler" =~ "PBS" ]]; then
      # UNIQUE_ID="${PBS_JOBID}_${PBS_ARRAY_INDEX:-0}_${PBS_TASKNUM:-0}"
      # SAFE_ID=$(echo "$UNIQUE_ID" | tr -cd '[:alnum:]_-')
      JOBTMP="$localScratchBase/$PBS_JOBID/${PBS_TASKNUM:-0}"
    fi
    echo "[$SECONDS] CVMFSExec executable will be extracted to $JOBTMP"
    setup_cvmfsexec_exe "$cvmfsexecExtra" "$JOBTMP"

    echo "[$SECONDS] Set CVMFS_BASE=$JOBTMP/.cvmfsexec"
    export CVMFS_BASE="$JOBTMP/.cvmfsexec/dist/cvmfs"
  fi
fi

# create unique Harvester workdirectory for each pilot
if [[ "$scheduler" =~ "SLURM" ]]; then
  HARVESTER_WORKDIR="$HARVESTER_ACCESS_POINT/${SLURM_JOB_ID}/${SLURM_PROCID}"
elif [[ "$scheduler" =~ "PBS" ]]; then
  HARVESTER_WORKDIR="$HARVESTER_ACCESS_POINT/${PBS_JOBID}/${PBS_TASKNUM:-0}"
else
  HARVESTER_WORKDIR="$HARVESTER_ACCESS_POINT"
fi

echo  [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "create new working directory (if needed) - "$HARVESTER_WORKDIR
if [ ! -e $HARVESTER_WORKDIR ] ; then mkdir -pv $HARVESTER_WORKDIR ; fi
cd $HARVESTER_WORKDIR
echo  [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Now in working directory - "${PWD}
echo

# create $MACHINEFEATURES/shutdowntime file to include SLURM_JOB_END_TIME
export MACHINEFEATURES=$HARVESTER_WORKDIR
echo $SLURM_JOB_END_TIME > $MACHINEFEATURES/shutdowntime

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


if [[ "$PANDA_QUEUE" =~ "Perlmutter" ]]; then
    #setup rucio client for voms code and rucio python libraries
    lsetup -q rucio emi prmon

    # export ALRB_CONT_CHOME=/pscratch/sd/u/usatlas/.alrb/container/apptainer
    # export ALRB_tmpScratch=/pscratch/sd/u/usatlas/.alrb/tmp
    export SCRATCH=/lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/IRI_workdir/scratch
    export ALRB_CONT_CHOME=$SCRATCH/container/apptainer/
    export ALRB_tmpScratch=$SCRATCH/container/tmp

    export ALRB_CONT_RUNPAYLOAD="/srv/myPayload.sh"
    export ALRB_CONT_SETUPFILE="/srv/myEnv.sh"

    # setup emi environment for arcprocy commanded needed by the pilot -
    alias setupATLAS='source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh'

    # Setup FRONTIER
    #DPBexport FRONTIER_SERVER="(serverurl=http://atlasfrontier-ai.cern.ch:8000/atlr)(serverurl=http://atlasfrontier2-ai.cern.ch:8000/atlr)(serverurl=http://atlasfrontier1-ai.cern.ch:8000/atlr)(proxyurl=http://frontiercache.nersc.gov:3128)"
    export FRONTIER_SERVER="(serverurl=http://atlasfrontier-ai.cern.ch:8000/atlr)(serverurl=http://atlasfrontier1-ai.cern.ch:8000/atlr)(serverurl=http://atlasfrontier2-ai.cern.ch:8000/atlr)(proxyurl=http://fiona8.ucsc.edu:6082)(proxyurl=http://v4f.hl-lhc.net:6082)(proxyurl=http://atlasbpfrontier.cern.ch:3127)(proxyurl=http://atlasbpfrontier.fnal.gov:3127)"
    export PATH=$PATH:/global/common/software/m2616/bin

    export latestPilotVer=$(readlink -f  $ATLAS_SW_BASE/atlas.cern.ch/repo/sw/PandaPilot/tar/pilot3.tar.gz | sed -e 's|.*pilot3-||' -e 's|.tar.gz$||')
    export latestNERSCPilotVer=$(readlink -f  /global/common/software/m2616/pilot/pilot3.tar.gz | sed -e 's|.*pilot3-||' -e 's|.tar.gz$||')

    echo
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Harvester Top level directory - "$HARVESTER_DIR
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Harvester accessPoint - "$HARVESTER_ACCESS_POINT
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Harvester ID - "$HARVESTER_ID
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Harvester Worker ID - "$HARVESTER_WORKER_ID
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Harvester workflow (MAPTYPE) - "$HARVESTER_MAPTYPE
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Harvester accessPoint - "$HARVESTER_ACCESS_POINT
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Harvester workdir for this job - "$HARVESTER_WORKDIR
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Pilot tar file - "$pilot_tar_file
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Container IMAGE_BASE - "$IMAGE_BASE
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "command to setup release in container - "$HARVESTER_CONTAINER_RELEASE_SETUP_FILE
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Number of Nodes to use - "$HARVESTER_NNODE
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Number of tasks for srun - "$HARVESTER_NTASKS
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "ATHENA_PROC_NUMBER - "$ATHENA_PROC_NUMBER
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "TMPDIR - $TMPDIR"
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Current directory - "$PWD
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Current hostname - "$(hostname -s)


    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] show_sorted_envars
    env | sort
    #DPBecho [$(date -u "+%m-%d-%y %H:%M:%S %Z")] show_selected_envars
    #DPBenv | grep -e PATH -e X509 -e ALRB -e ATLAS_LOCAL_ROOT_BASE -e SLURM -e TMPDIR
    echo

    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] alias
    alias

    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "latestPilotVer - "$latestPilotVer
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "latestNERSCPilotVer - "$latestNERSCPilotVer


    # create container environmental file
    if [ -e myEnv.sh ] ; then rm -v myEnv.sh ; fi
cat <<EOF >>myEnv.sh
# Created on $(date # : <<-- this will be evaluated before cat;)
export PATH=\$PATH:/global/common/software/m2616/bin
EOF

    echo "export HARVESTER_ID="$HARVESTER_ID >> myEnv.sh
    echo "export HARVESTER_WORKER_ID="$HARVESTER_WORKER_ID >> myEnv.sh
    echo "export X509_USER_PROXY="$X509_USER_PROXY >> myEnv.sh
    echo "export X509_CERT_DIR="$X509_CERT_DIR >> myEnv.sh
    echo "export X509_VOMS_DIR="$X509_VOMS_DIR >> myEnv.sh
    echo "export X509_VOMSES="$X509_VOMSES >> myEnv.sh
    # added for token communiation between pilot and panda server
    echo "export PANDA_AUTH_ORIGIN="${PANDA_AUTH_ORIGIN} >> myEnv.sh
    echo "export PANDA_AUTH_TOKEN="${PANDA_AUTH_TOKEN} >> myEnv.sh
    echo lsetup -q \"python pilot-default-SL9\" >> myEnv.sh
    echo "lsetup -q rucio xrootd davix psutil logstash" >> myEnv.sh
    # echo "export ALRB_CONT_CHOME=/pscratch/sd/u/usatlas/.alrb/container/apptainer" >> myEnv.sh
    echo "export ALRB_CONT_CHOME=$SCRATCH/container/apptainer/" >> myEnv.sh
    echo "export MACHINEFEATURES="$MACHINEFEATURES >> myEnv.sh
    # echo "export GTAG=https://portal.nersc.gov/cfs/m2616/PanDA_logs/slurm-"$SLURM_JOB_ID".out" >> myEnv.sh
    # echo "export GTAG=https://portal.nersc.gov/cfs/m2616/PanDA_logs/IRI/${HARVESTER_WORKER_ID}/${HARVESTER_WORKER_ID}_stdout.txt" >> myEnv.sh
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Container enviromental setup file (myEnv.sh) - "
    cat myEnv.sh
    echo

    # create exection file
    if [ -e myPayload.sh ] ; then /bin/rm -v myPayload.sh ; fi
cat <<EOF2 >>myPayload.sh
#!/bin/sh
# Created on $(date # : <<-- this will be evaluated before cat;)
EOF2

    echo "echo show sorted envars inside container running the PanDA pilot" >> myPayload.sh
    echo "env | sort " >> myPayload.sh
    echo " " >> myPayload.sh
    echo "voms-proxy-info -all" >> myPayload.sh
    echo " " >> myPayload.sh
    # echo "python3 /global/common/software/m2616/pilot/pilot3-"$latestNERSCPilotVer"/pilot3/pilot.py -q "$PANDA_QUEUE" -i PR -j managed -w generic --url https://pandaserver.cern.ch --pilot-user ATLAS --allow-same-user=False --getjobrequests=150 --notokenrenewal --cleanup True   --noworkerpilotstatusupdate -x 50 --debug" >> myPayload.sh
    # echo "python3 /global/common/software/m2616/pilot/pilot3-"$latestNERSCPilotVer"/pilot3/pilot.py -q "$PANDA_QUEUE" -i PR -j managed -w generic --url https://pandaserver.cern.ch --pilot-user ATLAS --allow-same-user=False --getjobrequests=150 --notokenrenewal --cleanup True   --noworkerpilotstatusupdate -x 50 --debug --noproxyverification " >> myPayload.sh
    echo "python3 /global/common/software/m2616/pilot/pilot3-"$latestNERSCPilotVer"/pilot3/pilot.py -q "$PANDA_QUEUE" -i PR -j user -w generic --url https://pandaserver.cern.ch --pilot-user ATLAS --allow-same-user=False --getjobrequests=150 --notokenrenewal --cleanup True   --noworkerpilotstatusupdate -x 50 --debug --noproxyverification " >> myPayload.sh

    chmod +x myPayload.sh

    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Container Payload file (myPayload.sh)- "
    cat myPayload.sh
    echo

    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] " executing_command_setupATLAS-c"
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] setupATLAS -v -v -v  -c el9 -m /global -m /pscratch 
    setupATLAS -v -v -v -c el9 -m /global -m /pscratch 
    echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "setupATLAS return_code - " $?
elif [[ "$PANDA_QUEUE" =~ "ALCF" ]]; then
  module use /soft/modulefiles
  module spack-pe-base
  module apptainer

  export HTTP_PROXY=http://proxy.alcf.anl.gov:3128
  export HTTPS_PROXY=http://proxy.alcf.anl.gov:3128
  export http_proxy=http://proxy.alcf.anl.gov:3128
  export https_proxy=http://proxy.alcf.anl.gov:3128

  export FRONTIER_SERVER="(serverurl=http://v4fa.cern.ch/atlr)(serverurl=http://v4fb.cern.ch/atlr)(proxyurl=http://proxy.alcf.anl.gov:3128)"

  export latestALCFPilotVer=$(readlink -f /lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/pilot/pilot3.tar.gz 2>/dev/null | sed -e 's|.*pilot3-||' -e 's|.tar.gz$||')

  IMAGE_AREA=/lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/harvester/image
  # export ATLAS_LOCAL_ROOT_BASE=/lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/harvester/alrb/ATLASLocalRootBase/
  # source "${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh"
  echo "[$SECONDS] Change directory to $HARVESTER_WORKDIR"
  cd "$HARVESTER_WORKDIR"

  echo "[$SECONDS] Done with setup, starting pilot wrapper"
  cmd="python3 /lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/pilot/pilot3-${latestALCFPilotVer}/pilot3/pilot.py -q \"$PANDA_QUEUE\" -i PR -j managed -w generic --url https://pandaserver.cern.ch --pilot-user ATLAS --allow-same-user=False --getjobrequests=150 --notokenrenewal --cleanup True --noworkerpilotstatusupdate -x 50 --debug --cvmfsbase $CVMFS_BASE --cleanup False"
  echo "$cmd" >> "$HARVESTER_WORKDIR/run.sh"
  echo "Running in el9 container:"
  echo "apptainer exec -B /lus/eagle/projects/ATLAS_workflow_ALCF/usatlas -B /home -B /lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/workdir/user/rwang/test/submitter /lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/harvester/image/atlas-grid-almalinux9.sif /lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/harvester/image/mount_cvmfs.sh $JOBTMP cvmfsexec_4.51_el9 $HARVESTER_WORKDIR/run.sh"
  apptainer exec -B /lus/eagle/projects/ATLAS_workflow_ALCF/usatlas -B /home -B /lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/workdir/user/rwang/test/submitter /lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/harvester/image/atlas-grid-almalinux9.sif /lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/harvester/image/mount_cvmfs.sh "$JOBTMP" cvmfsexec_4.51_el9 "$HARVESTER_WORKDIR/run.sh"

fi

