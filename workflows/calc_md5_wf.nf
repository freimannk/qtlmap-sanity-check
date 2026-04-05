#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// Header log info
log.info """=========================================="""
def summary = [:]
summary['Pipeline Name']        = 'Generate MD5 hash pipeline'
summary['Current home']         = "$HOME"
summary['Current user']         = "$USER"
summary['Current path']         = "$PWD"
summary['Config Profile']       = workflow.profile


if(params.email) summary['E-mail Address'] = params.email
log.info summary.collect { k,v -> "${k.padRight(21)}: $v" }.join("\n")
log.info "========================================="

include { calculate_md5} from '../modules/calc_md5.nf'


workflow {
    calc_md5()
}
    
workflow calc_md5 {
    take:
        study_ch
    main:

    grouped_by_study_id_ch = study_ch
            .groupTuple(by: 0)
    grouped_by_study_id_ch_dests = grouped_by_study_id_ch
           .map { study_id, srcs , dests->
              tuple(study_id, dests.unique())
           }
    calculate_md5(grouped_by_study_id_ch_dests)
}