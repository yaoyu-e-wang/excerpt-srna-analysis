import "single_sample_excerpt_workflow.wdl" as single_sample_process
import "report.wdl" as reporting

workflow ExcerptSmallRna {

    Array[File] fastq_files
    String genome_id
    File excerpt_genome_database
    String output_zip_name
    String git_repo_url
    String git_commit_hash

    scatter( fq in fastq_files ) {
        call single_sample_process.SingleSampleExcerptRun as ss_process{
            input:
                fastq = fq,
                genome_id = genome_id,
                genome_database = excerpt_genome_database
        }
    }

    call merge_outputs {
        input:
            core_results = ss_process.core_results
    }

    call reporting.generate_report as generate_report {
        input:
            fastq_files = fastq_files,
            genome = genome_id,
            git_repo_url = git_repo_url,
            git_commit_hash = git_commit_hash
    }

    call zip_results {
        input:
            zip_name = output_zip_name,
            all_excerpt_files = merge_outputs.all_outputs,
            report = generate_report.report
    }

    output {
        File zip_out = zip_results.zip_out
    }

    meta {
        workflow_title : "ExceRpt Small-RNA Processing"
        workflow_short_description : "For characterizing the nature and quantity of small RNA species"
        workflow_long_description : "Use this workflow for alignment and characterization of small RNA-Seq experiments."
    }


}

task merge_outputs {

    Array[Array[File]] core_results
    String output_dir = "merged_excerpt_outputs"

    Int disk_size = 100

    Array[File] flat_core_results = flatten(core_results)

    command {
        mkdir ./target_dir
        mkdir ${output_dir}
        mv -t ./target_dir ${sep=" " flat_core_results}
        Rscript /opt/scripts/merge_runs.R ./target_dir ${output_dir}
    }

    output {
        Array[File] all_outputs = glob("${output_dir}/*")
    }

    runtime {
        docker: "docker.io/blawney/excerpt:v0.0.1"
        cpu: 6
        memory: "10 G"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: 0
    }

}

task zip_results {

    String zip_name 
    Array[File] all_excerpt_files
    File report

    Int disk_size = 50

    command {

        mkdir report
        mkdir report/exceRpt_output

        mv ${report} report/
        mv -t report/exceRpt_output ${sep=" " all_excerpt_files}

        zip -r "${zip_name}.zip" report
    }

    output {
        File zip_out = "${zip_name}.zip"
    }

    runtime {
        docker: "docker.io/blawney/excerpt:v0.0.1"
        cpu: 2
        memory: "6 G"
        disks: "local-disk " + disk_size + " HDD"
        preemptible: 0
    }
}
