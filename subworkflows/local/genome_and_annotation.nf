
include { LONGEST                             } from '../../modules/local/longest'
include { BUSCO_BUSCO                         } from '../../modules/nf-core/busco/busco/main'
include { QUAST                               } from '../../modules/nf-core/quast/main'
include { AGAT_SPSTATISTICS                   } from '../../modules/nf-core/agat/spstatistics/main'
//include { GFFREAD                             } from '../../modules/nf-core/gffread/main'
include { GFFREAD                             } from '../../modules/local/gffread'
include { ORTHOFINDER                         } from '../../modules/nf-core/orthofinder/main'

workflow GENOME_AND_ANNOTATION {

    take:
    ch_fasta // channel: [ val(meta), [ fasta ] ]
    ch_gff // channel: [ val(meta), [ gff ] ]

    main:

    ch_versions = Channel.empty()
    // For tree plot
    ch_tree_data = Channel.empty()

    // TODO nf-core: substitute modules here for the modules of your subworkflow

    //
    // Run Quast
    //

    QUAST (
        ch_fasta,
        [[],[]],
        ch_gff
    )
    ch_versions = ch_versions.mix(QUAST.out.versions.first())

    // For tree

    ch_tree_data = ch_tree_data.mix(QUAST.out.tsv.map { tuple -> tuple[1] })

    //
    // Run AGAT Spstatistics
    //

    AGAT_SPSTATISTICS (
        ch_gff
    )
    ch_versions = ch_versions.mix(AGAT_SPSTATISTICS.out.versions.first())

    //
    // Run AGAT longest isoform
    //

//    LONGEST (
//        ch_gff
//    )
//    ch_versions = ch_versions.mix(LONGEST.out.versions.first())
//
//    //
//    // Run GFFREAD
//    //
//
//    ch_long_gff = LONGEST.out.longest_proteins
//    
    inputChannel = ch_gff.combine(ch_fasta, by: 0)

    // Split the input channel into two channels
    gffChannel = inputChannel.map { tuple ->
        // Extracting the GFF path and ID
        [tuple[0], tuple[1]]
    }
    fnaChannel = inputChannel.map { tuple ->
        // Extracting only the FNA path
        [tuple[0], tuple[2]]
    }

    GFFREAD ( 
        fnaChannel,
        gffChannel
    )
    ch_versions = ch_versions.mix(GFFREAD.out.versions.first())

    //
    // MODULE: Run Orthofinder
    //

    ortho_ch = GFFREAD.out.longest.collect().map { it -> [[id:"orthofinder"], it] }

    ORTHOFINDER (
        ortho_ch,
        [[],[]]
    )
    ch_versions = ch_versions.mix(ORTHOFINDER.out.versions)

    //
    // MODULE: Run BUSCO
    //

    BUSCO_BUSCO (  
        GFFREAD.out.proteins_busco, 
        "proteins", // Hard coded, it's the only possible option
        params.busco_lineage,
        params.busco_lineages_path ?: [],
        params.busco_config ?: []
    )
    ch_versions = ch_versions.mix(BUSCO_BUSCO.out.versions.first())

    ch_tree_data = ch_tree_data.mix(BUSCO_BUSCO.out.batch_summary.collect { meta, file -> file })

    emit:
    orthofinder = ORTHOFINDER.out.orthofinder // channel: [ val(meta), [folder] ]
    //busco = BUSCO_BUSCO.out.batch_summary.collect { meta, file -> file }
    tree_data = ch_tree_data.flatten().collect()
    busco_mq = BUSCO_BUSCO.out.short_summaries_txt.map { meta, file -> file } 
    quast_mq = QUAST.out.results.map { meta, file -> file }

    versions = ch_versions                     // channel: [ versions.yml ]
}

