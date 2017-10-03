module Labors
  class Victim < Magma::Model
    parent :monster

    identifier :name, type: String
    attribute :country, type: String
  end
end
