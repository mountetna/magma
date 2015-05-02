class Sample < Magma::Model
  many_to_one :patient

  identifier :sample_name, type: String, desc: "Unique name for this sample"
  attribute :tumor_type, type: String, desc: "Tumor type for this sample"
  attribute :weight, type: Float, desc: "Mass in grams"
  attribute :site, type: String, desc: "Site of biopsy/extraction"
  attribute :stage, type: String, desc: "Stage of tumor"
  attribute :grade, type: String, desc: "Tumor grade"
  attribute :physician, type: String, desc: "Contact person who provided access to the sample"
  attribute :ice_time, type: DateTime, desc: "Time that the sample spent on ice before flow"
  attribute :description, type: String, desc: "General description - how gross the sample looks"
  attribute :date_of_flow, type: DateTime, desc: "Date when flow panel was run"
  attribute :date_of_digest, type: DateTime, desc: "Date when digest was done"
  attribute :date_of_extraction, type: DateTime, desc: "Date when sample was extracted"
  attribute :post_digest_cell_count, type: Integer, desc: "Count of cells available after digest"
end
