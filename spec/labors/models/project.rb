class Project < Magma::Model
  identifier :name, type: String, desc: "Name for this project"

  collection :labors
end
