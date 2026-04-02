#!/usr/bin/env nextflow
nextflow.enable.dsl=2

import java.security.MessageDigest

def hashPath(p) {
    def md = MessageDigest.getInstance("MD5")
    md.update(p.toString().bytes)
    return md.digest().encodeHex().toString()[0..7]
}
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
        // ch = study_ch
        //     .map { study_id, src ->
        //         tuple("output_" + study_id, file(src))
        //     }
        grouped_by_study_id_ch = study_ch
            .groupTuple(by: 0) // tuple (study_id, [p1,p2])
        check_pqs(grouped_by_study_id_ch, "output")
        // groupTuple study_id QTS1001, [p1, p2]. QTS334, [p1]
        detect_corrupted_files(check_pqs.out.scanned_corruped_files)
        count_sumstats_all_pqs(study_ch, "sumstats_batches", "all")
        susie_batches_cs_pqs(study_ch, "susie_batches", "cs")
        susie_batches_full_pqs(study_ch, "susie_batches", "full")
        susie_batches_lbf_pqs(study_ch, "susie_batches", "lbf")
    } else {
    // dest_ch = study_ch
    //     .groupTuple(by: 2)
    //     .map { study_ids, srcs, dest ->
    //         def tag = (study_ids.size() == 1) ?
    //             "published_" + study_ids[0] :
    //             "published_" + hashPath(dest)
    //         tuple(tag, file(dest))
    //     }
    grouped_by_study_id_ch = study_ch
            .groupTuple(by: 0)
    grouped_by_study_id_ch_dests = grouped_by_study_id_ch
           .map { study_id, srcs , dests->
              tuple(study_id, dests.unique())
           }
    grouped_by_study_id_ch_dests.view()
    check_pqs(grouped_by_study_id_ch_dests, "published")
    detect_corrupted_files(check_pqs.out.scanned_corruped_files)
    }

}