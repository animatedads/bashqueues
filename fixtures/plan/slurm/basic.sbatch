#!/bin/bash
#SBATCH --job-name=align
#SBATCH --partition=cpu
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
./align.sh
