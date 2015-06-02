class Experiment < Magma::Model
  identifier :name, type: String, desc: "Name for this experiment"
  parent :project
  attribute :description, type: String, desc: "General description of the goals and methods"
  collection :patient, display_name: "Patients", desc: "List of patients associated with this experiment"
end
