# A single RNAseq experiment. Holds some gene expression data

class RnaSeq < Magma::Model
  identifier :tube_name, type: String, desc: "Name of tube containing RNA", 
    match: Proc.new { IPI.match_rna_seq_name }, 
    format_hint: "<sample_name>.rna.<type>, e.g. IPICRC001.T1.rna.myeloid"

  parent :sample
  link :rna_seq_plate

  # Source files
  table :fastq, desc: "List of Fastq pairs"
  document :bam_file, desc: "Alignment file used to generate gene expression counts"
  document :bam_index, desc: "Index for bam_file"

  #sample info
  attribute :compartment, type: String, desc: "What cell type it came from", match: IPI::CELL_TYPES
  attribute :cell_number, type: Integer, desc: "Number of input cells"
  attribute :expression_type, type: String, desc: "Descriptor of normalized gene expression, e.g. RPKM, FPKM, TPM, etc."
  attribute :transcriptome_build, type: String, desc: "What transcriptome build this sample was aligned against."

  table :gene_exp

  # flagstats
  attribute :read_count, type: Integer, desc: "Total count of reads"
  attribute :duplicate_count, type: Integer, desc: "Count of duplicated reads"
  attribute :mapped_count, type: Integer, desc: "Count of mapped reads"

  # composition information from picard
  attribute :intergenic_count, type: Integer, desc: "Count of intergenic reads" # comes from picard + bwa_picard
  attribute :introns_count, type: Integer, desc: "Count of intronic reads" # picard + bwa_picard
  attribute :utr_count, type: Integer, desc: "Count of reads in UTRs (including non-coding RNA)" # this comes from picard
  attribute :coding_count, type: Integer, desc: "Count of all protein-coding reads, excluding chrM" # this comes from picard
  attribute :mt_coding_count, type: Integer, desc: "Count of MT protein-coding reads" # comes from counting reads on chrM or summing gexp table
  attribute :rrna_count, type: Integer, desc: "Count of all reads aligning to cytoplasmic rRNA"
  attribute :mt_rrna_count, type: Integer, desc: "Count of all reads aligning to MT-rRNA" # this comes from the soak step

  # fragmentation stats
  attribute :median_3prime_bias, type: Float, desc: "Median 3-prime bias score" # this comes from picard
  attribute :median_cv_coverage, type: Float, desc: "Median coefficient of variance for coverage"
  attribute :transcript_histogram, type: :jsonb, desc: "Histogram of read counts along normalized transcript" # this comes from picard
  attribute :eisenberg_score, type: Integer, desc: "Number of Eisenberg housekeeping genes with normal expression" # 0-10 pre-calculated from data
end
