process check_pqs {
    tag "${study_id}"
    publishDir "${params.outdir}/validation/scanned_pqs_raports", mode: 'copy'
    container = 'quay.io/kfkf33/duckdb_env'

    input:
    tuple val(study_id), path(loc_paths)
    val(prefix)

    output:
    path("${prefix}_${study_id}_scanned_pqs_raport.log")
    tuple val(study_id), path("${prefix}_${study_id}_scanned_pqs_raport.tsv"), emit: scanned_corruped_files

    script:

    """
    check_pqs.py -d ${loc_paths} -o ${prefix}_${study_id}_scanned_pqs_raport
    """
}

process detect_corrupted_files {
    tag "check_corrupted_${study_id}"
    errorStrategy { task.exitStatus == 10 ? 'ignore' : 'terminate' }

    input:
    tuple val(study_id), path(input_file)

    output:
    path("done_${study_id}.log")

    script:
    """
    set -euo pipefail

    n=\$((\$(wc -l < ${input_file}) - 1))

    if [ "\$n" -gt 0 ]; then
        echo "ERROR: Found \$n corrupted files in ${study_id}!" >&2
        exit 10
    else
        echo "No corrupted files found."
    fi

    touch done_${study_id}.log
    """
}

process count_subfolder_pqs {
    tag "${selected_type}-${study_id}-${sub_folder}"
    publishDir "${params.outdir}/validation/subfolder_file_counts/${study_id}", mode: 'copy'

    input:
    tuple val(study_id), path(base_dirs)
    val(selected_type)
    val(sub_folder)


    output:
    path("${study_id}_${selected_type}_${sub_folder}.tsv")


    script:
    """
    count_pqs.sh \
    ${base_dirs.join(' ')} \
    ${sub_folder} \
    ${selected_type} \
    ${study_id}

    """
}
