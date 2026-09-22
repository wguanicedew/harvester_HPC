#!/bin/sh -l
#PBS -l system=crux
#PBS -l place=scatter
#PBS -l walltime=1:00:00
#PBS -q debug
#PBS -A ATLAS_workflow_ALCF
#PBS -l filesystems=home:eagle
#PBS -k doe
#PBS -o {stdout_path}
#PBS -e {stderr_path}

## end of shifter PBS extentions

export TZ=UTC0

echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] Start_PBS_Job

cd {work_dir}

export PANDA_QUEUE={pandaQueueName}
# export HARVESTER_DIR=/global/common/software/m2616/harvester-perlmutter/venv/py_3_13_11
export HARVESTER_DIR=/lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/harvester/harvester-crux

export HARVESTER_ACCESS_POINT={work_dir}
export HARVESTER_TASKS_PER_NODE=4 # Should be equal to: (nJobsPerWorker * nCorePerNode) / nCore
export HARVESTER_NNODE={nNode}
export HARVESTER_NTASKS=$((HARVESTER_TASKS_PER_NODE * HARVESTER_NNODE))
export HARVESTER_MAPTYPE=NoJob

export PANDA_JSID=harvester-{harvesterID}
export HARVESTER_ID={harvesterID}
export HARVESTER_WORKER_ID={workerID}
export GTAG={gtag}
export APFMON=http://apfmon.lancs.ac.uk/api
export APFFID={harvesterID}

if [ -n "{pandaTokenFilename}" ] && [ -f "{pandaTokenFilename}" ] && [ -n "{pandaTokenKeyPath}" ] && [ -f "{pandaTokenKeyPath}" ]; then
    export PANDA_AUTH_ORIGIN={tokenOrigin}
    export PANDA_AUTH_TOKEN=$(pwd)/{pandaTokenFilename}
    export PANDA_AUTH_TOKEN_KEY=$(pwd)/{pandaTokenKeyPath}
    # export PANDA_AUTH_ID_TOKEN=$(cat $PANDA_AUTH_TOKEN)
    echo "Using PANDA_AUTH_TOKEN: $PANDA_AUTH_TOKEN"
else
    echo "PANDA_AUTH_TOKEN not found or not accessible"
fi

if [ -n "{x509UserProxy}" ] && [ -f "{x509UserProxy}" ]; then
    export X509_USER_PROXY=$(pwd)/{x509UserProxy}
    echo "Using X509_USER_PROXY: $X509_USER_PROXY"
else
    echo "X509_USER_PROXY not found or not accessible"
fi


if [[ -n "${input_archive}" ]]; then
    echo "Extracting input archive: ${input_archive}"
    cp ${input_archive} .
    echo tar -xzf $(basename ${input_archive})
    tar -xzf $(basename ${input_archive})
fi


# alrb
export ATLAS_LOCAL_ROOT_BASE=/lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/harvester/alrb/ATLASLocalRootBase

# cvmfsexec
export cvmfsexecExtra=/lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/software/harvester/image/cvmfsexec_4.51_el9
export localScratchBase=/lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/IRI_workdir/cvmfsexec_cache/

export Local_Pilot=/lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/IRI_workdir/pilot_env/pilot3-3.14.4.19/pilot.py

export prodsourcelabel=user

# Careful, bash can only do integer math.
export ATHENA_PROC_NUMBER_JOB=$((256 / (HARVESTER_TASKS_PER_NODE)))
export ATHENA_PROC_NUMBER=$((256 / (HARVESTER_TASKS_PER_NODE)))
export ATHENA_CORE_NUMBER=$((256 / (HARVESTER_TASKS_PER_NODE)))


#DPB_shifter export wrapper_wrapper_file=$HARVESTER_DIR/etc/panda/wrapper-wrapper-3-shifter.sh
# export wrapper_wrapper_file=$HARVESTER_DIR/etc/panda/wrapper-wrapper-3.sh
# export wrapper_wrapper_file=/global/cfs/cdirs/m2616/harvester_workdir/pilot_env/wrapper-wrapper-3.sh
# export wrapper_wrapper_file=/lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/IRI_workdir/pilot_env/alcf_wrapper-wrapper-3.sh
export wrapper_wrapper_file=/lus/eagle/projects/ATLAS_workflow_ALCF/usatlas/IRI_workdir/pilot_env/harvester_HPC/alcf_wrapper-wrapper-3.sh

echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] "Copy $wrapper_wrapper_file into $HARVESTER_ACCESS_POINT"
#DPB_shifter cp -v $wrapper_wrapper_file $HARVESTER_ACCESS_POINT/wrapper-wrapper-3-shifter.sh
cp -v $wrapper_wrapper_file $HARVESTER_ACCESS_POINT/wrapper-wrapper-3.sh

#DPB_shifter echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] srun --label -n $HARVESTER_NTASKS /usr/bin/shifter /bin/bash ./wrapper-wrapper-3-shifter.sh $PANDA_QUEUE $HARVESTER_ACCESS_POINT
#DPB_shifter srun --label -n $HARVESTER_NTASKS /usr/bin/shifter /bin/bash ./wrapper-wrapper-3-shifter.sh $PANDA_QUEUE $HARVESTER_ACCESS_POINT
#echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] srun --label -n $HARVESTER_NTASKS  /bin/bash ./wrapper-wrapper-3.sh $PANDA_QUEUE $HARVESTER_ACCESS_POINT
#srun --label -n $HARVESTER_NTASKS  /bin/bash ./wrapper-wrapper-3.sh $PANDA_QUEUE $HARVESTER_ACCESS_POINT
# echo [$(date -u "+%m-%d-%y %H:%M:%S %Z")] srun --export=HARVESTER_ID,HARVESTER_WORKER_ID,PANDA_AUTH_ORIGIN,PANDA_AUTH_TOKEN --label -n $HARVESTER_NTASKS  /bin/bash ./wrapper-wrapper-3.sh $PANDA_QUEUE $HARVESTER_ACCESS_POINT
# srun --export=HARVESTER_ID,HARVESTER_WORKER_ID,PANDA_AUTH_ORIGIN,PANDA_AUTH_TOKEN --label -n $HARVESTER_NTASKS  /bin/bash ./wrapper-wrapper-3.sh $PANDA_QUEUE $HARVESTER_ACCESS_POINT
# wait

source /etc/profile
source /opt/cray/pe/lmod/lmod/init/profile

# module load python/3.13-26.8.0
# module load cray-python/3.11.7
module load cray-python

echo "pbs job id: $PBS_JOBID" | sed -e "s/^/pilot_${PBS_TASKNUM}: /"
echo "pbs task id: $PBS_TASKNUM" | sed -e "s/^/pilot_${PBS_TASKNUM}: /"
echo "pbs ncpus: $NCPUS" | sed -e "s/^/pilot_${PBS_TASKNUM}: /"

# env

/bin/bash ./wrapper-wrapper-3.sh $PANDA_QUEUE $HARVESTER_ACCESS_POINT | sed -e "s/^/pilot_${PBS_TASKNUM}: /"

# not working with request node is busy
# srun --export=ALL --label --ntasks=1 --cpus-per-task=$SLURM_CPUS_PER_TASK /bin/bash ./wrapper-wrapper-3.sh $PANDA_QUEUE $HARVESTER_ACCESS_POINT | sed -e "s/^/pilot_${SLURM_PROCID}: /"


# chown -R :m2616 $HARVESTER_ACCESS_POINT
