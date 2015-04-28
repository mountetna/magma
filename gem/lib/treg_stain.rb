class TregStain < Magma::Model
  many_to_one :flow_dat
  identifer :tube_name, type: String, desc: "Name of tube containing stain"
  attribute :total_stained_count, type: Integer, desc: "Total count of cells stained (estimate)"
  attribute :total_acquired_count, type: Integer, desc: "Total count of cells acquired by flow machine"
  attribute :live_count, type: Integer, desc: "Total count of live cells after staining"
  attribute :treg_count, type: Integer, desc: "Total count of T-reg cells after staining"
  attribute :teff_count, type: Integer, desc: "Total count of T-effector cells after staining"
end
