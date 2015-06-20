class Project < Magma::Model
  identifier :name, type: String, desc: "Name for this project"

  attribute :description, type: String

  collection :experiment

  collection :document
end
