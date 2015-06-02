class SortStain < Magma::Model
  identifier :tube_name, type: String, desc: "Name of tube containing stain"
  parent :sample
  attribute :total_stained_count, type: Integer, desc: "Total count of cells stained (estimate)"
  attribute :total_acquired_count, type: Integer, desc: "Total count of cells acquired by flow machine"
  attribute :live_count, type: Integer, desc: "Total count of live cells after staining"
  attribute :cd45_count, type: Integer
  attribute :lineage_neg_count, type: Integer, desc: "Total count of CD19,CD56 negative cells"
  attribute :stroma_count, type: Integer, desc: "Total count of stromal cells after staining"
  attribute :myeloid_count, type: Integer, desc: "Total count of myeloid cells after staining"
  attribute :t_count, type: Integer, desc: "Total count of t cells after staining"
  attribute :tumor_count, type: Integer, desc: "Total count of tumors"
  document :facs_file, desc: "FACS format file for this stain"
end
