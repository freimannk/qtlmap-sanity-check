process concate_QTD_susie_full {
    tag "${qtd}-susie_full"
    container = 'quay.io/kfkf33/duckdb_env'

    input:
    tuple val(row_group_key), val(study_id), val(qtd), path(src_dir), val(src_base), val(dest_base)

    output:
    tuple val(row_group_key), val(study_id), val(qtd), val(src_base), val(dest_base), path("${qtd}.full_susie.parquet")

    script:
    """
    concatenate_full_susie.py \
        -i ${src_dir} \
        -o ${qtd}.full_susie.parquet \
        -m ${task.memory.toGiga()} \
        -t ${task.cpus}
    """
}

process copy_concatenated_susie_batches {
    tag "susie_batches-${study_id}"

    input:
    tuple val(row_group_key), val(study_id), val(qtd), val(src_base), val(dest), path(full_susie)

    output:
    path("done_${study_id}.log")
    tuple val(row_group_key), val(study_id), val(qtd), val(src_base), val(dest), emit: susie_batches_data

    script:
    """
    set -euo pipefail

    DEST=${dest}/susie_batches/${study_id}/${qtd}
    mkdir -p "\$DEST"
    rsync -avL ${full_susie} "\$DEST/"

    touch done_${study_id}.log
    """
}

process copy_sumstats {
    tag "sumstats-${study_id}"

    input:
    tuple val(row_key), val(study_id), path(src), val(dest)

    output:
    path("done_${study_id}.log")
    tuple val(row_key), val(study_id), path(src), val(dest), emit: sumstats_data

    script:
    """
    set -euo pipefail

    cp_folder_parquets.sh ${src} ${dest} sumstats ${study_id}

    touch done_${study_id}.log
    """
}

process copy_susie {
    tag "susie-${study_id}"

    input:
    tuple val(row_key), val(study_id), path(src), val(dest)

    output:
    path("done_${study_id}.log")
    tuple val(row_key), val(study_id), path(src), val(dest), emit: susie_data

    script:
    """
    set -euo pipefail

    cp_folder_parquets.sh ${src} ${dest} susie ${study_id}

    touch done_${study_id}.log
    """
}