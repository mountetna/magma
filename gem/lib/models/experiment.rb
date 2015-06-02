class Experiment < Magma::Model
  identifier :name, type: String, desc: "Name for this experiment"
  parent :project
  attribute :description, type: String, desc: "General description of the goals and methods"
  collection :sample, desc: "List of samples associated with this experiment"
end
