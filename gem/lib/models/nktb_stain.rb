class NktbStain < Magma::Model
  identifier :tube_name, type: String, desc: "Name of tube containing stain",
    match: IPI.match_tube_name(:nktb), format_hint: "<sample_name>.nktb, e.g. IPICRC001.T1.nktb"
  parent :sample
  attribute :total_stained_count, type: Integer, desc: "Total count of cells stained (estimate)", default: 0
  attribute :total_acquired_count, type: Integer, desc: "Total count of cells acquired by flow machine", default: 0
  attribute :live_count, type: Integer, desc: "Total count of live cells after staining", default: 0
  attribute :cd45_count, type: Integer, desc: "Total count of CD45+ cells (total immune) after staining", default: 0
  attribute :t_count, type: Integer, desc: "Total count of T-cells after staining", default: 0
  attribute :nk_count, type: Integer, desc: "Total count of NK cells after staining", default: 0
  attribute :b_count, type: Integer, desc: "Total count of B cells after staining", default: 0
  document :facs_file, desc: "FACS format file for this stain"
end
