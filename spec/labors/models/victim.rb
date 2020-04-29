module Labors
  class Victim < Magma::Model
    parent :monster

    restricted

    identifier :name
    string :country, restricted: true
  end
end
