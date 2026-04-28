process sig_hits {
    tag "${study_id}_${dataset}"

    conda "/gpfs/helios/home/a82371/.conda/envs/qtl_stats"

    input:
    tuple val(study_id), path(src_dir), val(dataset), path(permutation_input_file)


    output:
    tuple val(study_id), val(dataset), path("${dataset}_significant_hits.tsv"), emit: sig_hits_summary

    script:
    """
    sig_hits.py \\
        -d "${dataset}" \\
        -p ${permutation_input_file} \\
        -o ${dataset}_significant_hits.tsv
    """
}