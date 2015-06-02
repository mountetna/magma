# A single RNAseq experiment. Holds some gene expression data

class RnaSeq < Magma::Model
  identifier :tube_name, type: String, desc: "Name of tube containing RNA", matches: /^IPI(CRC|MEL)[0-9]+\.rna/, format_desc: "<ipinumber>.<celltype>.rna, e.g. IPICRC001.treg.rna"
  parent :sample
  collection :gene_exp
  attribute :compartment, type: String, desc: "What cell type it came from"
  attribute :cell_number, type: Integer, desc: "Number of input cells"
  attribute :mass, type: Float, desc: "Mass in picograms of input sequence"
  attribute :expression_type, type: String, desc: "Descriptor of normalized gene expression, e.g. RPKM, FPKM, TPM, etc."
end
