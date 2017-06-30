class Prize < Magma::Model
  parent :labor

  attribute :name, type: String
  attribute :worth, type: Integer
end
