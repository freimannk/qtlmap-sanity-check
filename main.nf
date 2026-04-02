nextflow.enable.dsl=2

include {cp_data} from './workflows/cp_wf'
include {credible_sets_stats} from './workflows/credible_set_stats_wf'
include {validation} from './workflows/validation_wf'
include {validation as publish_validation} from './workflows/validation_wf'


workflow check_qtlmap_output {
    study_ch = Channel.fromPath(params.input)
        .splitCsv(header: true, sep: '\t')
        .map { row ->
            tuple(
                row.study_id,
                file(row.src_path)
            )
        }

    validation(study_ch, "output")
    credible_sets_stats(study_ch)
    

}

workflow publish_qtlmap_output {
    study_ch = Channel.fromPath(params.input)
        .splitCsv(header: true, sep: '\t')
        .map { row ->
            tuple(
                row.study_id,
                file(row.src_path),
                file(row.dest_path)
            )
        }

    def validation_input_ch = params.copy_data ? cp_data(study_ch).cp_ch : study_ch

    if (params.validation) {
        publish_validation(validation_input_ch, "publish")
    }

    // if (params.calculate_md5sums) {
    //     calculate_md5sums(validation_input_ch)
    // }
    }
        

workflow {
    check_qtlmap_output()
    publish_qtlmap_output()
}

