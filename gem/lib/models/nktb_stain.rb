class NktbStain < Magma::Model
  many_to_one :flow_dat
  identifier :tube_name, type: String, desc: "Name of tube containing stain"
  attribute :total_stained_count, type: Integer, desc: "Total count of cells stained (estimate)"
  attribute :total_acquired_count, type: Integer, desc: "Total count of cells acquired by flow machine"
  attribute :live_count, type: Integer, desc: "Total count of live cells after staining"
  attribute :cd45_count, type: Integer, desc: "Total count of CD45+ cells (total immune) after staining"
  attribute :t_count, type: Integer, desc: "Total count of T-cells after staining"
  attribute :nk_count, type: Integer, desc: "Total count of NK cells after staining"
  attribute :b_count, type: Integer, desc: "Total count of B cells after staining"
end
