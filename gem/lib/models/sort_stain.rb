class SortStain < Magma::Model
  identifier :tube_name, type: String, desc: "Name of tube containing stain",
    match: IPI.match_tube_name(:sort),
    format_hint: "<sample_name>.sort, e.g. IPICRC001.T1.sort"
  parent :sample
  attribute :total_stained_count, type: Integer, desc: "Total count of cells stained (estimate)", default: 0
  attribute :total_acquired_count, type: Integer, desc: "Total count of cells acquired by flow machine", default: 0
  attribute :live_count, type: Integer, desc: "Total count of live cells after staining", default: 0
  attribute :cd45_count, type: Integer, desc: "Total count of CD45+ cells", default: 0
  attribute :lineage_count, type: Integer, desc: "Total count of lineage positive cells", default: 0
  attribute :lineage_neg_count, type: Integer, desc: "Total count of CD19,CD56 negative cells", default: 0
  attribute :stroma_count, type: Integer, desc: "Total count of stromal cells after staining", default: 0
  attribute :myeloid_count, type: Integer, desc: "Total count of myeloid cells after staining", default: 0
  attribute :t_count, type: Integer, desc: "Total count of t cells after staining", default: 0
  attribute :tumor_count, type: Integer, desc: "Total count of tumors", default: 0
  document :facs_file, desc: "FACS format file for this stain", default: 0
end
