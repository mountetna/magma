module Labors
  class Monster < Magma::Model
    parent :labor

    identifier :name, type: String
    attribute :species, type: String, match: /^[a-z\s]+$/
    collection :victim
    table :aspect
  end
end
