
// set shorter versions of the  the passed parameter names
THREADS = params.threads
PLATFORM = params.platform 
OUT_DIR = params.outDir

DBSNP = params.dbsnp
KNOWN_INDELS = params.knownIndels
REF_FASTA = params.refFasta
ENSEMBL_GENE_ANNOTATIONS = params.ensemblGeneAnnotation
TEMPLATE_DIR=params.templateDir
CUSTOM_RUN_NAME = params.customRunName

// process ExtractFilesFromSampleDir{
//     input:
//     val(srcPath)
//     output
// }
process RunFastQC {
    tag "$sample"
    publishDir "${OUT_DIR}/fastqc", mode: 'copy'
    when:
    !params.skipQc && !params.skipFastQc

    input:
    set val(sample), file(reads)

    output:
    file "*.{zip,html}"
    file '.command.out'

    script:
    template "${TEMPLATE_DIR}/run_fastqc.sh"
}



process MapReads {
    echo true
    tag "$sample"
    publishDir "${OUT_DIR}/align/"
    input:
    set val(sample), file(reads)

    output:
    file("${sample}.cram")
    file '.command.log'

    script:
    r1 = reads[0]
    r2 = reads[1]
    
    script:
    template "${TEMPLATE_DIR}/map_reads.sh"
}

process CreateRecalibrationTable{
    echo true
    tag "$sample"
    publishDir "${OUT_DIR}/misc/recal_table/", mode: 'copy'

    input:
    file (sample_cram)
    
    output:
    file(sample_cram)
    file("${sample}.recal.table")
    file '.command.log'
    
    script:
    sample = "${sample_cram.baseName}" 
    template "${TEMPLATE_DIR}/create_recalibration_table.sh"
}

process ApplyBQSR {
    echo true
    tag "$sample"
    publishDir "${OUT_DIR}/misc/BQSR/", mode: 'copy'

    input:
    file(sample_cram) 
    file(recalibrated_file)

    
    output:
    file("${sample}.bqsr.bam")
    file("${sample}.bqsr.bai")

    script:
    sample = "${sample_cram.baseName}"
    template "${TEMPLATE_DIR}/apply_bqsr.sh"
}

process RunMultiQC {
    publishDir "${OUT_DIR}/multiqc", mode: 'copy'

    input:
    file (fastqc:'fastqc/*')
    file ('gatk_base_recalibration/*')
    file ('gatk_variant_eval/*')
    
    output:
    file '*multiqc_report.html'
    file '*_data'
    file '.command.err'
    val prefix

    script:
    prefix = fastqc[0].toString() - '_fastqc.html' - 'fastqc/'
    rtitle = CUSTOM_RUN_NAME ? "--title \"$CUSTOM_RUN_NAME\"" : ''
    rfilename = CUSTOM_RUN_NAME ? "--filename " + CUSTOM_RUN_NAME.replaceAll('\\W','_').replaceAll('_+','_') + "_multiqc_report" : ''
    """
    multiqc -f $rtitle $rfilename  . 2>&1
    
    """
}

