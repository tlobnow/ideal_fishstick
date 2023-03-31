#!/bin/bash -l
#SBATCH -J 6_RLX
#SBATCH --ntasks=1
#SBATCH --constraint="gpu"
#
# We will use 2 GPUs:
#SBATCH --gres=gpu:a100:2
#SBATCH --cpus-per-task=36
#SBATCH --mem=250000
#
# When using >1 GPUs, please adapt the variable XLA_PYTHON_CLIENT_MEM_FRACTION as well (see below)!
#SBATCH --mail-type=NONE
#SBATCH --mail-user=$USER@mpiib-berlin.mpg.de
#SBATCH --time=24:00:00

set -e

### LOAD MODULES #############################################################
module load anaconda/3/2021.11
module load cuda/11.4
module load nvidia-dali/gpu-cuda-11.4/

### LIBRARY & AI AVAILABILITY ################################################
export LD_LIBRARY_PATH=/mpcdf/soft/SLE_15/packages/x86_64/alphafold/2.3.0/lib:/mpcdf/soft/SLE_15/packages/x86_64/cuda/11.4.2/lib64
export TMPDIR=${JOB_SHMTMPDIR} # put temporary files into a ramdisk

### ENABLE CUDA UNIFIED MEMORY ###############################################
export TF_FORCE_UNIFIED_MEMORY=1
        # Enable jax allocation tweak to allow for larger models, note that
        # with unified memory the fraction can be larger than 1.0 (=100% of single GPU memory):
        # https://jax.readthedocs.io/en/latest/gpu_memory_allocation.html
        # When using 3 GPUs:
export XLA_PYTHON_CLIENT_MEM_FRACTION=6.0
        # run threaded tools with the correct number of threads (MPCDF customization)
export NUM_THREADS=${SLURM_CPUS_PER_TASK}
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}

### TARGETS & LOCATIONS #######################################################
source 00_user_parameters.inc
source 01_user_parameters.inc

### GIVE ECHO #################################################################
echo "Info: target file is $TARGET_LST_FILE"
echo "Info: input directory of unrelaxed models is $OUT_DIR"
echo "Info: output directory of relaxed models is $OUT_DIR"

### RUN #######################################################################
#srun $PYTHON_PATH/python3 -u $AF_DIR/run_af2c_min.py \
srun /mpcdf/soft/SLE_15/packages/x86_64/alphafold/2.3.0/bin/python3 -u $AF_DIR/run_af2c_min.py \
  --target_lst_path=$TARGET_LST_FILE \
  --output_dir=$OUT_DIR \
  --input_dir=$OUT_DIR
