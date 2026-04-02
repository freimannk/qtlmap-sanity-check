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

include {cs_stats } from '../modules/cs_stats'

workflow {
    credible_sets_stats()
}
    
workflow credible_sets_stats {
    take:
        study_ch
    main:
    dataset_ch = study_ch
        .flatMap { study_id, src_path ->

            def susie_dir = file("${src_path}/susie")

            if (!susie_dir.exists()) {
                return []
            }

            def qtd_dirs = susie_dir.listFiles()
                .findAll { it.isDirectory() && it.name.startsWith('QTD') }

            qtd_dirs.collectMany { qtd_dir ->

                def pq_files = qtd_dir.listFiles()
                    .findAll { it.name.endsWith(".credible_sets.parquet") }

                pq_files.collect { pq ->
                    tuple(
                        study_id,
                        file(src_path),
                        qtd_dir.name,
                        file(pq)
                    )
                }
            }
        }


    cs_stats(dataset_ch)


}