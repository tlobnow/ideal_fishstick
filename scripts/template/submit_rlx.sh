#!/bin/bash

set -e

JOBID1=$(sbatch --parsable script3_relaxation.sh)

echo "Submitted jobs" 
echo " ${JOBID1} (RLX ALL)"
