class DcStain < Magma::Model
  identifier :tube_name, type: String, desc: "Name of tube containing stain", match: IPI.match_tube_name(:dc), format_hint: "<sample_name>.dc, e.g. IPICRC001.T1.dc"
  parent :sample
  attribute :total_stained_count, type: Integer, desc: "Total count of cells stained (estimate)", default: 0
  attribute :total_acquired_count, type: Integer, desc: "Total count of cells acquired by flow machine", default: 0
  attribute :live_count, type: Integer, desc: "Total count of live cells", default: 0
  attribute :cd45_count, type: Integer, default: 0
  attribute :lineage_count, type: Integer, desc: "Total count of lineage+ cells", default: 0
  attribute :hladr_count, type: Integer, desc: "Total count of HLADR+ cells", default: 0
  attribute :hladr_lineage_negative_count, type: Integer, desc: "Total count of HLADR- lineage- cells", default: 0
  attribute :neutrophil_count, type: Integer, desc: "Total count of neutrophils", default: 0
  attribute :monocyte_count, type: Integer, desc: "Total count of monocytes", default: 0
  attribute :peripheral_dc_count, type: Integer, desc: "Total count of peripheral dendritic cells", default: 0
  attribute :cd11c_count, type: Integer, desc: "Total count of CD11c+ cells", default: 0
  attribute :dc1_count, type: Integer, desc: "Total count of DC1 dendritic cells", default: 0
  attribute :dc2_count, type: Integer, desc: "Total count of DC2 dendritic cells", default: 0
  attribute :cd14_pos_tam_count, type: Integer, desc: "Total count of CD14+ tumor-associated macrophages", default: 0
  attribute :cd14_neg_tam_count, type: Integer, desc: "Total count of CD14- tumor-associated macrophages", default: 0
  document :facs_file, desc: "FACS format file for this stain"
end
