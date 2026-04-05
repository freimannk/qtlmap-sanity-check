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
        keyed_study_ch = study_ch.map { study_id, src_base, dest_base ->
            def row_key = "${study_id}__${src_base}__${dest_base}"
            tuple(row_key, study_id, src_base, dest_base)
        }

        copy_sumstats(keyed_study_ch)
        copy_susie(keyed_study_ch)

        if (!params.concate_full_susie_batches) {
            cp_ch = copy_sumstats.out.sumstats_data
                .join(copy_susie.out.susie_data, by: 0)
                .map { row_key, study_id1, src1, dest1, study_id2, src2, dest2 ->
                    tuple(study_id1, src1, dest1)
                }
        } else {
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
                tuple(row_group_key, study_id, src_base, dest_base)
            }
            .groupTuple(by: 0)
            .map { row_group_key, study_ids, srcs, dests ->
                tuple(row_group_key.getGroupTarget(), study_ids[0], srcs[0], dests[0])
            }

        cp_ch = copy_sumstats.out.sumstats_data
            .join(copy_susie.out.susie_data, by: 0)
            .join(susie_batches_done, by: 0)
            .map { row_key, study_id1, src1, dest1, study_id2, src2, dest2, study_id3, src3, dest3 ->
                tuple(study_id1, src1, dest1)
    }
        }
        copy_sumstats.out.sumstats_data.view { "SUMSTATS_OUT => $it" }
        copy_susie.out.susie_data.view { "SUSIE_OUT => $it" }
        cp_ch.view { "CP_CH => $it" }


    emit:
        cp_ch
}