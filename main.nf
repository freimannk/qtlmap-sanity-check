nextflow.enable.dsl=2


process check_pqs {
    publishDir "${params.outdir}", mode: 'copy'
    container = 'quay.io/kfkf33/duckdb_env'

    input:

    output:
    path("${params.corrupted_parquets_output}.txt")

    script:
    """
    check_pqs.py -d ${params.scanned_dir} -o ${params.corrupted_parquets_output}
    """
}

workflow {
    check_pqs()
}

