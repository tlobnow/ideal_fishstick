#!/bin/bash

set -e

JOBID1=$(sbatch --parsable script2_comp_model_2.sh)

echo "Submitted jobs"
echo "    ${JOBID1} (PRED 2)"
