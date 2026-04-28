#!/usr/bin/env nextflow
nextflow.enable.dsl=2


// Header log info
log.info """=========================================="""
def summary = [:]
summary['Pipeline Name']        = 'Credible set stats generation pipiline'
summary['Current home']         = "$HOME"
summary['Current user']         = "$USER"
summary['Current path']         = "$PWD"
summary['Config Profile']       = workflow.profile
summary["PIP threshold:"]       = params.pip_threshold


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

    cs_summary_by_study_ch = cs_stats.out.cs_summary
    .map { study_id, dataset, tsv ->
        tuple(study_id, dataset, tsv)
    }
    .groupTuple(by: 0)
    .flatMap { study_id, datasets, tsvs ->
        def out = []
        for (int i = 0; i < tsvs.size(); i++) {
            out << tuple(study_id, datasets[i], tsvs[i])
        }
        return out
    }
    .collectFile(
        keepHeader: true,
        skip: 1,
        storeDir: "${params.outdir}/cs_stats"
    ) { study_id, dataset, tsv ->
        [ "${study_id}_cs_summary.tsv", tsv ]
    }


cs_size_stats_by_study_ch = cs_stats.out.cs_size_stats
    .map { study_id, dataset, tsv ->
        tuple(study_id, dataset, tsv)
    }
    .groupTuple(by: 0)
    .flatMap { study_id, datasets, tsvs ->
        def out = []
        for (int i = 0; i < tsvs.size(); i++) {
            out << tuple(study_id, datasets[i], tsvs[i])
        }
        return out
    }
    .collectFile(
        keepHeader: true,
        skip: 1,
        storeDir: "${params.outdir}/cs_stats"
    ) { study_id, dataset, tsv ->
        [ "${study_id}_cs_size_stats_summary.tsv", tsv ]
    }


    cs_per_trait_stats_by_study_ch = cs_stats.out.cs_per_trait_stats
    .map { study_id, dataset, tsv ->
        tuple(study_id, dataset, tsv)
    }
    .groupTuple(by: 0)
    .flatMap { study_id, datasets, tsvs ->
        def out = []
        for (int i = 0; i < tsvs.size(); i++) {
            out << tuple(study_id, datasets[i], tsvs[i])
        }
        return out
    }
    .collectFile(
        keepHeader: true,
        skip: 1,
        storeDir: "${params.outdir}/cs_stats"
    ) { study_id, dataset, tsv ->
        [ "${study_id}_cs_per_molecular_trait_id_stats_summary.tsv", tsv ]
    }


}