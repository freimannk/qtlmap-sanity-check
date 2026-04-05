#!/bin/bash

#SBATCH --time=01:00:00
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --mem=6G
#SBATCH --job-name="check_qtlmap"
#SBATCH --partition=amd


module load any/jdk/1.8.0_265
module load nextflow
module load any/singularity/3.7.3
module load squashfs/4.4


#nextflow run main.nf -profile tartu_hpc,test -resume -entry check_qtlmap_output --input data/testdata/test_publish_input.tsv --outdir testdata
#nextflow run main.nf -profile tartu_hpc,test -resume --input data/testdata/test_publish_input.tsv --outdir testdata
nextflow run main.nf -profile tartu_hpc -resume -entry check_qtlmap_output --input data/AFR_LCL.tsv --outdir AFR_LCL