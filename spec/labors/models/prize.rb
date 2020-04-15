module Labors
  class Prize < Magma::Model
    parent :labor

    string :name
    integer :worth
  end
end


