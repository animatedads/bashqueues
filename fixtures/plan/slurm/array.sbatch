#!/bin/bash
#SBATCH --job-name=array-demo
#SBATCH --array=1-10
#SBATCH --time=00:10:00
./worker.sh "$SLURM_ARRAY_TASK_ID"
