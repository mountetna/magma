# A single RNAseq experiment. Holds some gene expression data

class RnaSeq < Magma::Model
  identifier :tube_name, type: String, desc: "Name of tube containing RNA", 
    match: IPI.rna_seq_name, 
    format_hint: "<sample_name>.rna.<cell_type>, e.g. IPICRC001.T1.rna.myel"
  parent :sample
  collection :gene_exp
  attribute :compartment, type: String, desc: "What cell type it came from"
  attribute :cell_number, type: Integer, desc: "Number of input cells"
  attribute :mass, type: Float, desc: "Mass in picograms of input sequence"
  attribute :expression_type, type: String, desc: "Descriptor of normalized gene expression, e.g. RPKM, FPKM, TPM, etc."
end
