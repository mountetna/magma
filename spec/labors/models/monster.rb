module Labors
  class Monster < Magma::Model
    parent :labor

    identifier :name, type: String
    string :species, match: /^[a-z\s]+$/
    collection :victim
    table :aspect
    file :stats
  end
end
