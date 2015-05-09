class Project < Magma::Model
  identifier :name, type: String, desc: "Name for this project"

  collection :experiment, desc: "List of experiments for this project"
end
