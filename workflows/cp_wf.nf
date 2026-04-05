#!/usr/bin/env nextflow
nextflow.enable.dsl=2

log.info """=========================================="""
def summary = [:]
summary['Pipeline Name'] = 'Copy selected data to new path'
summary['Current home'] = "$HOME"
summary['Current user'] = "$USER"
summary['Current path'] = "$PWD"
summary['Config Profile'] = workflow.profile
summary['Concatenate susie batches full dir'] = params.concate_full_susie_batches

if (params.email) summary['E-mail Address'] = params.email
log.info summary.collect { k, v -> "${k.padRight(35)}: $v" }.join("\n")
log.info "========================================="

include { copy_sumstats; copy_susie; concate_QTD_susie_full; copy_concatenated_susie_batches } from '../modules/copy_data'

workflow {
    cp_data()
}

workflow cp_data {
    take:
        study_ch

    main:
        /*
         * row_key makes each input row unique even when study_id repeats
         */
        keyed_study_ch = study_ch.map { study_id, src_base, dest_base ->
            def row_key = [study_id, src_base.toString(), dest_base.toString()]
            tuple(row_key, study_id, src_base, dest_base)
        }

        copy_sumstats(keyed_study_ch)
        copy_susie(keyed_study_ch)

        def susie_batches_done = Channel.empty()

        if (params.concate_full_susie_batches) {
            def qtd_ch = keyed_study_ch.flatMap { row_key, study_id, src_base, dest_base ->
                def susie_batches_dir = file("${src_base}/susie_batches")
                def qtd_dirs = susie_batches_dir.exists()
                    ? (susie_batches_dir.listFiles()?.findAll { it.name.startsWith('QTD') } ?: [])
                    : []

                if (!qtd_dirs) {
                    return []
                }

                qtd_dirs.collect { qtd_dir ->
                    tuple(
                        groupKey(row_key, qtd_dirs.size()),
                        study_id,
                        qtd_dir.name,
                        file("${qtd_dir}/full"),
                        src_base,
                        dest_base
                    )
                }
            }

            concate_QTD_susie_full(qtd_ch)
            copy_concatenated_susie_batches(concate_QTD_susie_full.out)

            susie_batches_done = copy_concatenated_susie_batches.out.susie_batches_data
                .map { row_group_key, study_id, qtd, src_base, dest_base ->
                    tuple(row_group_key, true)
                }
                .groupTuple()
                .map { row_group_key, done_flags ->
                    tuple(row_group_key.getGroupTarget(), true)
                }
        }

        all_done = copy_sumstats.out.sumstats_data
            .map { row_key, study_id, src_base, dest_base ->
                tuple(row_key, 'sumstats')
            }
            .mix(
                copy_susie.out.susie_data.map { row_key, study_id, src_base, dest_base ->
                    tuple(row_key, 'susie')
                }
            )
            .mix(
                susie_batches_done.map { row_key, done ->
                    tuple(row_key, 'susie_batches')
                }
            )
            .groupTuple(by: 0, size: params.concate_full_susie_batches ? 3 : 2)
            .map { row_key, labels ->
                tuple(row_key, true)
            }

        cp_ch = keyed_study_ch
            .join(all_done)
            .map { row_key, study_id, src_base, dest_base, done ->
                tuple(study_id, src_base, dest_base)
            }

    emit:
        cp_ch
}