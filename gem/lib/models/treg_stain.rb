class TregStain < Magma::Model
  identifier :tube_name, type: String, desc: "Name of tube containing stain", match: IPI.match_tube_name(:treg), format_hint: "<sample_name>.treg, e.g. IPICRC001.T1.treg"
  parent :sample
  attribute :total_stained_count, type: Integer, desc: "Total count of cells stained (estimate)", default: 0
  attribute :total_acquired_count, type: Integer, desc: "Total count of cells acquired by flow machine", default: 0
  attribute :live_count, type: Integer, desc: "Total count of live cells after staining", default: 0
  attribute :treg_count, type: Integer, desc: "Total count of T-reg cells after staining", default: 0
  attribute :teff_count, type: Integer, desc: "Total count of T-effector cells after staining", default: 0
  attribute :t_count, type: Integer, desc: "Total count of T-cells after staining", default: 0
  attribute :hladr_count, type: Integer, desc: "Total count of HLADR+ cells after staining", default: 0
  attribute :cd4_count, type: Integer, desc: "Total count of CD4+ cells after staining", default: 0
  attribute :cd45_count, type: Integer, desc: "Total count of CD45+ cells after staining", default: 0
  attribute :cd8_count, type: Integer, desc: "Total count of CD8+ cells after staining", default: 0
  attribute :cd3_neg_count, type: Integer, desc: "Total count of CD3e- cells after staining", default: 0
  document :facs_file, desc: "FACS format file for this stain"
end
