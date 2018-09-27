module Labors
  class Aspect < Magma::Model
    parent :monster

    # this dictionary tells us how to validate Aspect
    dictionary Labors::Codex,
      monster: :monster,
      name: :aspect,
      source: :tome,
      value: :lore

    # the aspect in question
    attribute :name, type: String
    # where the aspect is codified
    attribute :source, type: String
    # the actual value
    attribute :value, type: String
  end
end
