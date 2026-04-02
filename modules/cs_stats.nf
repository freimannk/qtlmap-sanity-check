process cs_stats {
    tag "${dataset}-stats"
    container = 'quay.io/kfkf33/duckdb_plots:v1'
    publishDir "${params.outdir}/cs_stats/${study_id}", mode: 'copy'

    input:
    tuple val(study_id), path(src_dir), val(dataset), path(cs_pq_file)

    output:
    path("*.tsv")
    path("*.png")

    script:
    """
    cs_stats.py \
        -d ${dataset} \
        -p ${cs_pq_file} \
        -t ${params.pip_threshold}
    """
}