class Imaging < Magma::Model
  parent :sample

  identifier :image_name, type: String, desc: "IPI name for this image", match: IPI.match_tube_name(:image), format_hint: "<sample_name>.image, e.g. IPICRC001.T1.image"
  attribute :cd45_count, type: Integer, desc: "Total count of CD45+ cells", default: 0
  attribute :cd4_count, type: Integer, desc: "Total count of CD4+ cells", default: 0
  attribute :cd3_count, type: Integer, desc: "Total count of CD3+ cells", default: 0
  document :tiff_file, display_name: "TIFF file", desc: "TIFF image of the section"
end
