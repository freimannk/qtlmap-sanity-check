#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// Header log info
log.info """=========================================="""
def summary = [:]
summary['Pipeline Name']        = 'Validation'
summary['Current home']         = "$HOME"
summary['Current user']         = "$USER"
summary['Current path']         = "$PWD"
summary['Config Profile']       = workflow.profile

if(params.email) summary['E-mail Address'] = params.email
log.info summary.collect { k,v -> "${k.padRight(21)}: $v" }.join("\n")
log.info "========================================="

include { check_pqs; detect_corrupted_files} from '../modules/validation'
include { count_subfolder_pqs as count_sumstats_all_pqs} from '../modules/validation'
include { count_subfolder_pqs as susie_batches_cs_pqs} from '../modules/validation'
include { count_subfolder_pqs as susie_batches_full_pqs} from '../modules/validation'
include { count_subfolder_pqs as susie_batches_lbf_pqs} from '../modules/validation'


workflow {
    validation()
}
    
workflow validation {
    take:
        study_ch
        method
    main:
    if(method=="output"){
        grouped_by_study_id_ch = study_ch
            .groupTuple(by: 0) // tuple (study_id, [p1,p2])
        check_pqs(grouped_by_study_id_ch, "output")
        detect_corrupted_files(check_pqs.out.scanned_corruped_files)
        count_sumstats_all_pqs(grouped_by_study_id_ch, "sumstats_batches", "all")
        susie_batches_cs_pqs(grouped_by_study_id_ch, "susie_batches", "cs")
        susie_batches_full_pqs(grouped_by_study_id_ch, "susie_batches", "full")
        susie_batches_lbf_pqs(grouped_by_study_id_ch, "susie_batches", "lbf")
    } else {
    grouped_by_study_id_ch = study_ch
            .groupTuple(by: 0)
    grouped_by_study_id_ch_dests = grouped_by_study_id_ch
           .map { study_id, srcs , dests->
              tuple(study_id, dests.unique())
           }
    check_pqs(grouped_by_study_id_ch_dests, "published")
    detect_corrupted_files(check_pqs.out.scanned_corruped_files)
    }

}