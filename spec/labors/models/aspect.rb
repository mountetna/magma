module Labors
  class Aspect < Magma::Model
    # this dictionary tells us how to validate Aspect
    dictionary Labors::Codex,
      monster: :monster,
      name: :aspect,
      source: :tome,
      value: :lore
  end
end
