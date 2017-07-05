class Population < Magma::Model
  parent :sample

  attribute :name,
    type: String,
    desc: "Name of this population"

  attribute :stain,
    type: String,
    desc: "Originating stain"

  attribute :count,
    type: Integer,
    desc: "Number of cells"

  attribute :ancestry,
    type: String,
    desc: "Chain of parent populations"

  table :mfi,
    desc: "Mean fluorescence intensities for this population"
end
