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

PANDA_QUEUE=$1
HARVESTER_ACCESS_POINT=$2

export TZ=UTC0

export HARVESTER_DIR=/global/common/software/m2616/harvester-perlmutter/venv/py_3_13_11

# create unique Harvester workdirectory for each pilot
HARVESTER_WORKDIR=$HARVESTER_ACCESS_POINT/${SLURM_JOBID}/${SLURM_PROCID}
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

export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
if [ -z $ATLAS_LOCAL_ROOT_BASE ]; then
    export ATLAS_LOCAL_ROOT_BASE=/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase
fi
echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] setup_ALRB
source ${ATLAS_LOCAL_ROOT_BASE}/user/atlasLocalSetup.sh --quiet
echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] finished_setup_ALRB
#setup rucio client for voms code and rucio python libraries
lsetup -q rucio emi prmon

# export ALRB_CONT_CHOME=/pscratch/sd/u/usatlas/.alrb/container/apptainer
# export ALRB_tmpScratch=/pscratch/sd/u/usatlas/.alrb/tmp
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

# Unset TMP
#unset TMPDIR

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
echo "export GTAG=https://portal.nersc.gov/cfs/m2616/PanDA_logs/IRI/${HARVESTER_WORKER_ID}/${HARVESTER_WORKER_ID}_stdout.txt" >> myEnv.sh
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
