module Labors
  class Aspect < Magma::Model
    parent :monster

    dictionary Labors::Codex,
      name: :aspect,
      source: :tome,
      value: :values

    # the aspect in question
    attribute :name, type: String
    # where the aspect is codified
    attribute :source, type: String
    # the actual value
    attribute :value, type: String
  end
end
