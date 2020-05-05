module Labors
  class Monster < Magma::Model
    parent :labor

    identifier :name
    string :species, validation: { type: "Regexp", value: /^[a-z\s]+$/ }
    collection :victim
    table :aspect
    file :stats
  end
end
