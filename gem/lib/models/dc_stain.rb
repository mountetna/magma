class DcStain < Magma::Model
  parent :sample
  identifier :tube_name, type: String, desc: "Name of tube containing stain"
  attribute :total_stained_count, type: Integer, desc: "Total count of cells stained (estimate)"
  attribute :total_acquired_count, type: Integer, desc: "Total count of cells acquired by flow machine"
  attribute :live_count, type: Integer, desc: "Total count of live cells"
  attribute :cd45_count, type: Integer
  attribute :t_count, type: Integer, desc: "Total count of t cells"
  attribute :neutrophil_count, type: Integer, desc: "Total count of neutrophils"
  attribute :monocyte_count, type: Integer, desc: "Total count of monocytes"
  attribute :peripheral_dc_count, type: Integer, desc: "Total count of peripheral dendritic cells"
  attribute :dc1_count, type: Integer, desc: "Total count of DC1 dendritic cells"
  attribute :dc2_count, type: Integer, desc: "Total count of DC2 dendritic cells"
  attribute :cd14_pos_tam_count, type: Integer, desc: "Total count of CD14+ tumor-associated macrophages"
  attribute :cd14_neg_tam_count, type: Integer, desc: "Total count of CD14- tumor-associated macrophages"
end
