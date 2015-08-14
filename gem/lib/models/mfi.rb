class Mfi < Magma::Model
  parent :population

  attribute :name,
    type: String,
    desc: "Name of antibody"

  attribute :fluor,
    type: String,
    desc: "Color of this channel"

  attribute :value,
    type: Float,
    desc: "Mean fluorescence intensity"
end
