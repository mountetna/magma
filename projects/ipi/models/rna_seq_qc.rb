class RnaSeqQc < Magma::Model
  one_to_one :rna_seq
  attribute :total_reads, type: Integer, desc: "Total count of reads for this experiment"
  attribute :rRNA_reads, type: Float, desc: "What cell type it came from"
  attribute :intergenic_reads, type: Float, desc: "What cell type it came from"
  attribute :coding_reads, type: Float, desc: "What cell type it came from"
  attribute :intronic_reads, type: Float, desc: "What cell type it came from"
  attribute :utr_reads, type: Float, desc: "What cell type it came from"
end
