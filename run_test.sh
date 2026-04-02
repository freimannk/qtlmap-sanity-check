#!/bin/bash

#SBATCH --time=06:30:00
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --mem=5G
#SBATCH --job-name="check_qtlmaps"
#SBATCH --partition=amd


module load any/jdk/1.8.0_265
module load nextflow
module load any/singularity/3.7.3
module load squashfs/4.4


#nextflow run main.nf -profile tartu_hpc -resume
#nextflow run main.nf -profile tartu_hpc,test -resume
nextflow run main.nf -profile tartu_hpc -resume --input /gpfs/helios/home/a82371/CHECK_QTLMAP_OUTPUTS/data/testdata/AFR_LCL.tsv --outdir AFR_LCL