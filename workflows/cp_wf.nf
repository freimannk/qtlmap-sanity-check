#!/usr/bin/env nextflow
nextflow.enable.dsl=2


// Header log info
log.info """=========================================="""
def summary = [:]
summary['Pipeline Name']        = 'Find trans-eQTL results'
summary['Current home']         = "$HOME"
summary['Current user']         = "$USER"
summary['Current path']         = "$PWD"
summary['Config Profile']       = workflow.profile

if(params.email) summary['E-mail Address'] = params.email
log.info summary.collect { k,v -> "${k.padRight(21)}: $v" }.join("\n")
log.info "========================================="

include { copy_sumstats; copy_susie; concate_QTD_susie_full; copy_concatenated_susie_batches} from '../modules/copy_data'

workflow {
    cp_data()
}
    
workflow cp_data {
    take:
        study_ch
    main:
    copy_sumstats(study_ch)
    copy_susie(study_ch)
    qtd_ch = study_ch
        .flatMap { study_id, src_base, dest_base ->

            def qtd_dirs = file("${src_base}/susie_batches").listFiles()
                .findAll { it.name.startsWith('QTD') }

            qtd_dirs.collect { qtd_dir ->
                tuple(
                    study_id,
                    qtd_dir.name,
                    file("${qtd_dir}/full"),
                    dest_base
                )
            }
        }
    concate_QTD_susie_full(qtd_ch)
    copy_concatenated_susie_batches(concate_QTD_susie_full.out)

    emit:
        cp_ch = study_ch  


}