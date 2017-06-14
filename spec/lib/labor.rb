class Labor < Magma::Model
  parent :project

  identifier :name, type: String

  child :monster

  attribute :number, type: Integer
  attribute :completed, type: Boolean
end
