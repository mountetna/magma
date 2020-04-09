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
    string :name
    # where the aspect is codified
    string :source
    # the actual value
    string :value
  end
end
