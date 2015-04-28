# A single RNAseq experiment. Holds some gene expression data

class RnaSeq < Magma::Model
  many_to_one :sample
  many_to_one :rnaseq_batch
  one_to_many :gene_exps
  attribute :compartment, type: String, desc: "What cell type it came from"
  attribute :cell_number, type: Integer, desc: "Number of input cells"
  attribute :mass, type: Float, desc: "Mass in picograms of input sequence"
  attribute :expression_type, type: String, desc: "Descriptor of normalized gene expression, e.g. RPKM, FPKM, TPM, etc."
end
