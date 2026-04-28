process check_pqs {
    tag "${study_id}"
    publishDir "${params.outdir}/validation/${study_id}", mode: 'copy', pattern: "${prefix}_${study_id}_corrupted_pq_raport.log"
    container = 'quay.io/kfkf33/duckdb_env'

    input:
    tuple val(study_id), path(loc_paths)
    val(prefix)

    output:
    path("${prefix}_${study_id}_corrupted_pq_raport.log")
    tuple val(study_id), path("${prefix}_${study_id}_corrupted_pq_raport.tsv"), emit: scanned_corruped_files

    script:

    """
    check_pqs.py -d ${loc_paths} -o ${prefix}_${study_id}_corrupted_pq_raport
    """
}

process detect_corrupted_files {
    tag "${study_id}_check_corrupted"
    errorStrategy { task.exitStatus == 10 ? 'ignore' : 'terminate' }

    input:
    tuple val(study_id), path(input_file)

    output:
    path("${study_id}_corrupted_pq_raport.log")

    script:
    """
    set -euo pipefail

    DONE_LOG="${study_id}_corrupted_pq_raport.log"

    echo "Checking corrupted files for ${study_id}" > "\$DONE_LOG"
    echo "Input file: ${input_file}" >> "\$DONE_LOG"
    echo "" >> "\$DONE_LOG"

    n=\$((\$(wc -l < ${input_file}) - 1))

    if [ "\$n" -gt 0 ]; then
        echo "ERROR: Found \$n corrupted files in ${study_id}!" | tee -a "\$DONE_LOG" >&2
        echo "" | tee -a "\$DONE_LOG" >&2
        echo "Corrupted file entries:" | tee -a "\$DONE_LOG" >&2
        cat ${input_file} | tee -a "\$DONE_LOG" >&2

        echo "" >> "\$DONE_LOG"
        echo "Validation result: FAILED" >> "\$DONE_LOG"

        exit 10
    else
        echo "No corrupted files found." | tee -a "\$DONE_LOG"
        echo "" >> "\$DONE_LOG"
        echo "Validation result: PASSED" >> "\$DONE_LOG"
    fi
    """
}

process count_subfolder_pqs {
    tag "${selected_type}-${study_id}-${sub_folder}"
    publishDir "${params.outdir}/validation/${study_id}", mode: 'copy'

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

process check_file_existance {
    tag "${selected_folder}-${study_id}"
    publishDir "${params.outdir}/validation/${study_id}", mode: 'copy'

    input:
    tuple val(study_id), path(base_dirs)
    val(selected_folder)


    output:
    tuple val(study_id), path("${study_id}_${selected_folder}_log.tsv")


    script:
    """
    check_file_existence.sh \
    ${base_dirs.join(' ')} \
    ${selected_folder} \
    ${study_id}

    """
}

process check_required_files {
    tag "check_required_${study_id}"

    errorStrategy { task.exitStatus == 10 ? 'ignore' : 'terminate' }

    input:
    tuple val(study_id), path(log_file)

    output:
    path("${study_id}.log")

    script:
    """
    set -euo pipefail

    DONE_LOG="${study_id}.log"

    echo "Checking required files for ${study_id}" > "\$DONE_LOG"
    echo "Input TSV log file: ${log_file}" >> "\$DONE_LOG"
    echo "" >> "\$DONE_LOG"

    required_col=\$(awk -F '\\t' '
        NR == 1 {
            for (i = 1; i <= NF; i++) {
                if (\$i == "required_files_present") {
                    print i
                    exit
                }
            }
        }
    ' ${log_file})

    if [ -z "\$required_col" ]; then
        echo "ERROR: Column required_files_present not found in ${log_file}" | tee -a "\$DONE_LOG" >&2
        exit 1
    fi

    n=\$(awk -F '\\t' -v col="\$required_col" '
        NR > 1 && \$col == "false" { count++ }
        END { print count + 0 }
    ' ${log_file})

    if [ "\$n" -gt 0 ]; then
        echo "ERROR: Found \$n datasets with missing required files in ${study_id}!" | tee -a "\$DONE_LOG" >&2
        echo "" | tee -a "\$DONE_LOG" >&2
        echo "Rows with missing required files:" | tee -a "\$DONE_LOG" >&2

        awk -F '\\t' -v col="\$required_col" '
            NR == 1 || \$col == "false"
        ' ${log_file} | tee -a "\$DONE_LOG" >&2

        echo "" >> "\$DONE_LOG"
        echo "Validation result: FAILED" >> "\$DONE_LOG"

        exit 10
    else
        echo "All required files are present for ${study_id}." | tee -a "\$DONE_LOG"
        echo "" >> "\$DONE_LOG"
        echo "Validation result: PASSED" >> "\$DONE_LOG"
    fi
    """
}
