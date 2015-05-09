class Experiment < Magma::Model
  parent :project
  identifier :name, type: String, desc: "Name for this experiment"
  attribute :description, type: String, desc: "General description of the goals and methods"

  collection :sample, desc: "List of samples associated with this experiment"
end
