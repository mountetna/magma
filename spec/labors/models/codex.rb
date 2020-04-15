module Labors
  class Codex < Magma::Model
    parent :project

    string :monster
    string :aspect
    string :tome
    match :lore
  end
end
