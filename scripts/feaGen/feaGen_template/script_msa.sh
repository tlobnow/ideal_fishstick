#!/bin/bash -l
#SBATCH -J AF2-MSA
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=54
#SBATCH --mail-type=NONE
#SBATCH --mail-user=$USER@mpiib-berlin.mpg.de
#SBATCH --time=06:00:00

# AlphaFold2 template submit script (single sequence case) for RAVEN @ MPCDF,
# please create a local copy and customize to your use case.
#
# Important: Access the AF2 data ONLY via ${ALPHAFOLD_DATA} provided by MPCDF,
# please don't create per-user copies of the database in '/ptmp' or '/u' for performance reasons.

set -e

module purge
module load anaconda/3/2021.11

# include parameters common to the CPU and the GPU steps
source 01_user_parameters.inc

# check if the directories set by the alphafold module do exist
if [ ! -d ${ALPHAFOLD_DATA} ]; then
  echo "Could not find ${ALPHAFOLD_DATA}. STOP."
  exit 1
fi
mkdir -p ${OUTPUT_DIR}


# make CUDA and AI libs accessible
export LD_LIBRARY_PATH=${ALPHAFOLD_HOME}/lib:${LD_LIBRARY_PATH}
# put temporary files into a ramdisk
export TMPDIR=${JOB_SHMTMPDIR}

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


## Variable settings collected and adapted from
## https://github.com/deepmind/alphafold/blob/main/docker/run_docker.py

# Path to directory of supporting data, contains 'params' dir.
#DOWNLOAD_DIR=${ALPHAFOLD_DATA}

# Path to the Uniref90 database for use by JackHMMER.
#uniref90_database_path = os.path.join(FLAGS.data_dir, 'uniref90', 'uniref90.fasta')
uniref90_database_path=/raven/ri/public_sequence_data/alphafold2/git-v2.3.0/data/uniref90/uniref90.fasta

# Path to the MGnify database for use by JackHMMER.
#mgnify_database_path = os.path.join( FLAGS.data_dir, 'mgnify', 'mgy_clusters_2018_12.fa')
mgnify_database_path=/raven/ri/public_sequence_data/alphafold2/git-v2.3.0/data/mgnify/mgy_clusters_2022_05.fa

# Path to the Uniprot database for use by JackHMMER.
#uniprot_database_path = os.path.join(FLAGS.data_dir, 'uniprot', 'uniprot.fasta')
uniprot_database_path=/raven/ri/public_sequence_data/alphafold2/git-v2.3.0/data/uniprot/uniprot.fasta

# Path to the BFD database for use by HHblits.
#bfd_database_path = os.path.join(FLAGS.data_dir, 'bfd', 'bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt')
bfd_database_path=/raven/ri/public_sequence_data/alphafold2/git-v2.3.0/data/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt

# Path to the Small BFD database for use by JackHMMER.
# small_bfd_database_path = os.path.join(FLAGS.data_dir, 'small_bfd', 'bfd-first_non_consensus_sequences.fasta')
small_bfd_database_path=/raven/ri/public_sequence_data/alphafold2/git-v2.3.0/data/small_bfd/bfd-first_non_consensus_sequences.fasta

# Path to the PDB seqres database for use by hmmsearch.
#pdb_seqres_database_path = os.path.join(FLAGS.data_dir, 'pdb_seqres', 'pdb_seqres.txt')
pdb_seqres_database_path=/raven/ri/public_sequence_data/alphafold2/git-v2.3.0/data/pdb_seqres/pdb_seqres.txt

# Path to the Uniclust30 database for use by HHblits.
#uniclust30_database_path = os.path.join(FLAGS.data_dir, 'uniclust30', 'uniclust30_2018_08', 'uniclust30_2018_08')
uniclust30_database_path=/raven/ri/public_sequence_data/alphafold2/git-v2.3.0/data/uniclust30/uniclust30_2018_08/uniclust30_2018_08

# Path to the PDB70 database for use by HHsearch.
# pdb70_database_path = os.path.join(FLAGS.data_dir, 'pdb70', 'pdb70')
pdb70_database_path=/raven/ri/public_sequence_data/alphafold2/git-v2.3.0/data/pdb70/pdb70

# Path to a directory with template mmCIF structures, each named <pdb_id>.cif.
#template_mmcif_dir = os.path.join(FLAGS.data_dir, 'pdb_mmcif', 'mmcif_files')
template_mmcif_dir=/raven/ri/public_sequence_data/alphafold2/git-v2.3.0/data/pdb_mmcif/mmcif_files

# Path to a file mapping obsolete PDB IDs to their replacements.
#obsolete_pdbs_path = os.path.join(FLAGS.data_dir, 'pdb_mmcif', 'obsolete.dat')
obsolete_pdbs_path=/raven/ri/public_sequence_data/alphafold2/git-v2.3.0/data/pdb_mmcif/obsolete.dat

srun /mpcdf/soft/SLE_15/packages/x86_64/alphafold/2.3.0/bin/python3 -u $AF_DIR/run_af2c_fea.py \
        --output_dir="${OUTPUT_DIR}" \
        --fasta_paths="${FASTA_PATHS}" \
        --db_preset="${PRESET}" \
        --data_dir=/raven/ri/public_sequence_data/alphafold2/git-v2.3.0/data \
        --uniref90_database_path=${uniref90_database_path} \
        --mgnify_database_path=${mgnify_database_path} \
        --small_bfd_database_path=${small_bfd_database_path} \
        --uniprot_database_path=${uniprot_database_path} \
        --pdb70_database_path=${pdb70_database_path} \
        --template_mmcif_dir=${template_mmcif_dir} \
        --max_template_date=$(date +"%Y-%m-%d") \
        --obsolete_pdbs_path=${obsolete_pdbs_path} \
        --hhblits_binary_path=${TOOL_DIR}/hhblits   \
        --hhsearch_binary_path=${TOOL_DIR}/hhsearch \
        --jackhmmer_binary_path=${TOOL_DIR}/jackhmmer \
        --hmmsearch_binary_path=${TOOL_DIR}/hmmsearch \
        --hmmbuild_binary_path=${TOOL_DIR}/hmmbuild \
        --kalign_binary_path=${TOOL_DIR}/kalign \
        --feature_mode='monomer+species' \
        --use_precomputed_msas=True



