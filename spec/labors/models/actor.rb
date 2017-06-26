class Prize < Magma::Model
  parent :labor

  identifier :name, type: String
  attribute :worth, type: Integer
end
