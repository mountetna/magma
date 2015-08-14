class Population < Magma::Model
  parent :sample

  parent :population,
    desc: "Parent population"

  attribute :name,
    type: String,
    desc: "Name of this population"

  attribute :stain,
    type: String,
    desc: "Originating stain"

  attribute :count,
    type: Integer,
    desc: "Number of cells"

  table :mfi,
    desc: "Mean fluorescence intensities for this population"
end
