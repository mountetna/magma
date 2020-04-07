module Labors
  class Victim < Magma::Model
    parent :monster

    restricted

    identifier :name, type: String
    string :country, restricted: true
  end
end
