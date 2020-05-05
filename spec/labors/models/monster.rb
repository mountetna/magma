module Labors
  class Monster < Magma::Model
    parent :labor

    identifier :name
    string :species, validation: /^[a-z\s]+$/
    collection :victim
    table :aspect
    file :stats
  end
end
