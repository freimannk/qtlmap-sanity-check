#!/usr/bin/env nextflow
nextflow.enable.dsl=2


// Header log info
log.info """=========================================="""
def summary = [:]
summary['Pipeline Name']        = 'QTL stats generation pipiline'
summary['Current home']         = "$HOME"
summary['Current user']         = "$USER"
summary['Current path']         = "$PWD"
summary['Config Profile']       = workflow.profile


if(params.email) summary['E-mail Address'] = params.email
log.info summary.collect { k,v -> "${k.padRight(21)}: $v" }.join("\n")
log.info "========================================="

include {sig_hits } from '../modules/qtl_stats'

workflow {
    qtl_stats()
}
    
workflow qtl_stats {
    take:
        study_ch
    main:
    dataset_ch = study_ch
        .flatMap { study_id, src_path ->

            def susie_dir = file("${src_path}/sumstats")

            if (!susie_dir.exists()) {
                return []
            }

            def qtd_dirs = susie_dir.listFiles()
                .findAll { it.isDirectory() && it.name.startsWith('QTD') }

            qtd_dirs.collectMany { qtd_dir ->

                def pq_files = qtd_dir.listFiles()
                    .findAll { it.name.endsWith(".permuted.parquet") }

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


sig_hits(dataset_ch)
sig_hits_by_study_ch = sig_hits.out.sig_hits_summary
    .map { study_id, dataset, summary_file ->
        tuple(study_id, dataset, summary_file)
    }
    .groupTuple(by: 0)
    .flatMap { study_id, datasets, summary_files ->

        def paired = [datasets, summary_files]
            .transpose()
            .sort { a, b -> a[0] <=> b[0] }

        paired.collect { dataset, summary_file ->
            tuple(study_id, dataset, summary_file)
        }
    }
    .collectFile(
        keepHeader: true,
        skip: 1,
        sort: false,
        storeDir: "${params.outdir}/qtl_stats"
    ) { study_id, dataset, summary_file ->
        [ "${study_id}_significant_hits_summary.tsv", summary_file ]
    }


}