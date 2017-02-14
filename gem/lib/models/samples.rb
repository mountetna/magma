class Sample < Magma::Model
  identifier :sample_name, match: Proc.new { IPI.match_sample_name }, format_hint: "IPICRC001.T1", type: String, desc: "Unique name for this sample"

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

  document :treg_file, 
    desc: "FACS format file for T-reg stain"

  document :nktb_file, 
    desc: "FACS format file for NKTB stain"

  document :sort_file, 
    desc: "FACS format file for Sort stain"

  document :dc_file, 
    desc: "FACS format file for DC stain"

  child :imaging,
    desc: "Immunofluorescence imaging of this sample"

  image :he_stain, display_name: "H&E staining",
    desc: "Flat image of H&E stain"

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

  attribute :description, 
    type: String, 
    desc: "General description - how gross the sample looks"

  attribute :post_digest_cell_count, 
    type: Integer, 
    desc: "Count of cells available after digest"
end
