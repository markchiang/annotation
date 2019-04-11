params.help = null
params.out_folder = "."
params.table_extension = "avinput"
params.thread = 16
cleanup = true

if (params.help) {
    log.info ''
    log.info '--------------------------------------------------'
    log.info '                   TABLE ANNOVAR                  '
    log.info '--------------------------------------------------'
    log.info ''
    log.info 'Usage: '
    log.info 'nextflow run table_annovar.nf --table_folder myinputfolder'
    log.info ''
    log.info 'Mandatory arguments:'
    log.info '    --table_folder       FOLDER            Folder containing tables to process.'
    log.info 'Optional arguments:'
    log.info '    --out_folder  FOLDER  Output will be stored in this folder, default to .'
    log.info ''
    exit 1
}

vcfs = Channel.fromPath( params.table_folder+'*.vcf')
                 .ifEmpty { error "empty table folder, please verify your input." }


process avinput {

  publishDir params.out_folder, mode: 'copy'

  input:
  file vcffile from vcfs

  output:
  file "*.avinput" into tables
  file "*.avinput" into output_avinput

  shell:
  '''
  convert2annovar.pl --includeinfo --withzyg -format vcf4 !{vcffile} -outfile !{vcffile}.avinput
  '''
}

process annovar {

  publishDir params.out_folder, mode: 'copy'

  tag { file_name }

  cpus params.thread

  input:
  file tables
  file ("*") from Channel.fromPath( '/home/markchiang/annotation/annovar/humandb/', type: 'dir' ).collect()

  output:
  file "*multianno.txt" into output_annovar

  shell:
  file_name = tables.baseName
  '''
  table_annovar.pl -nastring NA -buildver hg19 --thread !{params.thread} --otherinfo -remove -protocol refGene,knownGene,ensGene,cytoBand,avsnp150,clinvar_20180603,cosmic70,dbnsfp35c,intervar_20180118,popfreq_all_20150413,kaviar_20150923,TWBioBank,gwasCatalog -operation g,g,g,r,f,f,f,f,f,f,f,f,r -otherinfo !{tables} humandb
  #sed -i '1s/Otherinfo/QUAL\tFILTER\tINFO\tFORMAT\tNORMAL\tPRIMARY\tID\tIndividual\tStudy/' !{tables}.hg19_multianno.txt
  '''
}

workflow.onComplete {

    user="whoami".execute().text

    summary = """

    Pipeline execution summary
    ---------------------------
    Completed at: ${workflow.complete}
    Duration    : ${workflow.duration}
    Success     : ${workflow.success}
    workDir     : ${workflow.workDir}
    exit status : ${workflow.exitStatus}
    Error report: ${workflow.errorReport ?: '-'}
    Git info: $workflow.repository - $workflow.revision [$workflow.commitId]
    User: ${user}
    """

    println summary

    output_avinput.subscribe { println "avinput: ${params.out_folder}/${it.baseName}.avinput" }
    output_annovar.subscribe { println "annotation: ${params.out_folder}/${it.baseName}.txt" }

    // mail summary
    // ['mail', '-s', 'wi-nf', params.email].execute() << summary
}
