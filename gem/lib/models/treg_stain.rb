class TregStain < Magma::Model
  identifier :tube_name, type: String, desc: "Name of tube containing stain", match: IPI.tube_name(:treg), format_hint: "<sample_name>.treg, e.g. IPICRC001.T1.treg"
  parent :sample
  attribute :total_stained_count, type: Integer, desc: "Total count of cells stained (estimate)"
  attribute :total_acquired_count, type: Integer, desc: "Total count of cells acquired by flow machine"
  attribute :live_count, type: Integer, desc: "Total count of live cells after staining"
  attribute :treg_count, type: Integer, desc: "Total count of T-reg cells after staining"
  attribute :teff_count, type: Integer, desc: "Total count of T-effector cells after staining"
  document :facs_file, desc: "FACS format file for this stain"
end
