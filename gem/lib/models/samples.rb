class Sample < Magma::Model
  identifier :sample_name, match: IPI.match_sample_name, format_hint: "IPICRC001.T1", type: String, desc: "Unique name for this sample"

  parent :patient

  table :population

  image :headshot, display_name: "Head shot",
    desc: "Gross picture of the sample"

  attribute :notes,
    type: String,
    desc: "General notes about this sample"

  attribute :processed,
    type: TrueClass,
    desc: "Whether sample was processed or discarded"

  child :treg_stain,
    display_name: "T-reg Stain",
    desc: "Stain for regulatory T-cells"

  child :nktb_stain,
    display_name: "NK/T/B Stain",
    desc: "Stain for NK, T and B cells"

  child :sort_stain,
    display_name: "Sort Stain",
    desc: "Stain for sorting cells into RNAseq compartments"

  child :dc_stain,
    display_name: "DC Stain",
    desc: "Stain for dendritic cells"

  child :imaging,
    desc: "Immunofluorescence imaging of this sample"

  collection :rna_seq, 
    display_name: "RNASeq Experiments",
    desc: "RNA Seq experiments performed on this sample"


  attribute :tumor_type, 
    type: String, 
    match: [ "Primary", "Metastasis", "Normal" ],
    desc: "Tumor type for this sample"

  attribute :weight, 
    type: Float, 
    desc: "Mass in grams"

  attribute :site, 
    type: String, 
    desc: "Site of biopsy/extraction"

  attribute :stage, 
    type: String, 
    desc: "Stage of tumor"

  attribute :grade, 
    type: String, 
    desc: "Tumor grade"

  attribute :physician, 
    type: String, 
    desc: "Contact person who provided access to the sample"

  attribute :ice_time, 
    type: Float,
    desc: "Time that the sample spent on ice before digestion (hours)"

  attribute :description, 
    type: String, 
    desc: "General description - how gross the sample looks"

  attribute :date_of_digest, 
    type: DateTime, 
    desc: "Date when digest was done"

  attribute :date_of_extraction, 
    display_name: "Date of Surgery",
    type: DateTime, 
    desc: "Date when sample was taken out of patient"

  attribute :post_digest_cell_count, 
    type: Integer, 
    desc: "Count of cells available after digest"
end
