# Gene expression for a single gene

class GeneExp < Magma::Model
  parent :rna_seq
  #parent :gene # points to a gene record in a table of genes somewhere, maybe later.
  attribute :ensembl_name, type: String, desc: "Ensembl gene ID"
  attribute :hugo_name, type: String, desc: "HGNC gene symbol" # this could be blank
  attribute :read_counts, type: Float, desc: "Raw counts of total reads aligned to this gene."
  attribute :expression, type: Float, desc: "Normalized estimate of gene expression."
end
