class StainPanel < Magma::Model
  parent :patient

  attribute :name, type: String

  collection :channel
end
