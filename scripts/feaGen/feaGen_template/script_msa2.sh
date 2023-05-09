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

#module purge
#module load anaconda/3/2021.11
#module load alphafold/2.3.0

module purge
module load cuda/11.4
module load alphafold/2.3.0

source ./msa_parameters.inc
# db preset
PRESET="full_dbs"

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

# run threaded tools with the correct number of threads
export NUM_THREADS=${SLURM_CPUS_PER_TASK}
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
# for the MSA phase we can only use the CPU
export CUDA_VISIBLE_DEVICES=""

# Path to the Uniref90 database for use by JackHMMER.
#uniref90_database_path = os.path.join(FLAGS.data_dir, 'uniref90', 'uniref90.fasta')
uniref90_database_path=${ALPHAFOLD_DATA}/uniref90/uniref90.fasta

# Path to the MGnify database for use by JackHMMER.
#mgnify_database_path = os.path.join( FLAGS.data_dir, 'mgnify', 'mgy_clusters_2018_12.fa')
mgnify_database_path=${ALPHAFOLD_DATA}/mgnify/mgy_clusters_2022_05.fa

# Path to the Uniprot database for use by JackHMMER.
#uniprot_database_path = os.path.join(FLAGS.data_dir, 'uniprot', 'uniprot.fasta')
uniprot_database_path=${ALPHAFOLD_DATA}/uniprot/uniprot.fasta

# Path to the BFD database for use by HHblits.
#bfd_database_path = os.path.join(FLAGS.data_dir, 'bfd', 'bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt')
bfd_database_path=${ALPHAFOLD_DATA}/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt

# Path to the Small BFD database for use by JackHMMER.
# small_bfd_database_path = os.path.join(FLAGS.data_dir, 'small_bfd', 'bfd-first_non_consensus_sequences.fasta')
small_bfd_database_path=${ALPHAFOLD_DATA}/small_bfd/bfd-first_non_consensus_sequences.fasta

# Path to the PDB seqres database for use by hmmsearch.
#pdb_seqres_database_path = os.path.join(FLAGS.data_dir, 'pdb_seqres', 'pdb_seqres.txt')
pdb_seqres_database_path=${ALPHAFOLD_DATA}/pdb_seqres/pdb_seqres.txt

# Path to the Uniref30 database for use by HHblits.
# uniref30_database_path = os.path.join( FLAGS.data_dir, 'uniref30', 'UniRef30_2021_03')
uniref30_database_path=${ALPHAFOLD_DATA}/uniref30/UniRef30_2021_03

# Path to the PDB70 database for use by HHsearch.
# pdb70_database_path = os.path.join(FLAGS.data_dir, 'pdb70', 'pdb70')
pdb70_database_path=${ALPHAFOLD_DATA}/pdb70/pdb70

# Path to a directory with template mmCIF structures, each named <pdb_id>.cif.
#template_mmcif_dir = os.path.join(FLAGS.data_dir, 'pdb_mmcif', 'mmcif_files')
template_mmcif_dir=${ALPHAFOLD_DATA}/pdb_mmcif/mmcif_files

# Path to a file mapping obsolete PDB IDs to their replacements.
#obsolete_pdbs_path = os.path.join(FLAGS.data_dir, 'pdb_mmcif', 'obsolete.dat')
obsolete_pdbs_path=${ALPHAFOLD_DATA}/pdb_mmcif/obsolete.dat

# run the application
srun ${ALPHAFOLD_HOME}/bin/python3 ${ALPHAFOLD_HOME}/app/alphafold/run_alphafold.py \
        --output_dir="${OUTPUT_DIR}" \
        --fasta_paths="${FASTA_PATHS}" \
        --db_preset="${PRESET}" \
        --data_dir="${ALPHAFOLD_DATA}" \
        --bfd_database_path=${bfd_database_path} \
        --uniref30_database_path=${uniref30_database_path} \
        --uniref90_database_path=${uniref90_database_path} \
        --mgnify_database_path=${mgnify_database_path} \
        --template_mmcif_dir=${template_mmcif_dir} \
        --obsolete_pdbs_path=${obsolete_pdbs_path} \
        --pdb_seqres_database_path=${pdb_seqres_database_path} \
        --uniprot_database_path=${uniprot_database_path} \
        --max_template_date="2022-12-21" \
        --model_preset=multimer \
        --run_msa_and_templates_only --nouse_gpu_relax
#       ^^^ last line: limit to msa and templates on the CPU, then STOP
