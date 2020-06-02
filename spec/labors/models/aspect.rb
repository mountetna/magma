module Labors
  class Aspect < Magma::Model
    # this dictionary tells us how to validate Aspect
    dictionary dictionary_model: "Labors::Codex",
      monster: :monster,
      name: :aspect,
      source: :tome,
      value: :lore
  end
end
