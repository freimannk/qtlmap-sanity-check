process cs_stats {
    tag "${dataset}-stats"
    container = 'quay.io/kfkf33/duckdb_plots:v1'
    publishDir "${params.outdir}/cs_stats/plots", mode: 'copy', pattern: "*.png"

    input:
    tuple val(study_id), path(src_dir), val(dataset), path(cs_pq_file)

    output:
    tuple val(study_id), val(dataset), path("${dataset}_summary.tsv"), emit: cs_summary
    tuple val(study_id), val(dataset), path("${dataset}_cs_size_stats.tsv"), emit: cs_size_stats
    tuple val(study_id), val(dataset), path("${dataset}_cs_per_molecular_trait_id_stats.tsv"), emit: cs_per_trait_stats
    path("*.png")

    script:
    """
    cs_stats.py \
        -s ${study_id} \
        -d ${dataset} \
        -p ${cs_pq_file} \
        -t ${params.pip_threshold}
    """
}