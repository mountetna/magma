class Experiment < Magma::Model
  identifier :name, type: String, desc: "Name for this experiment"
  parent :project
  attribute :description, 
    type: String, 
    desc: "General description of the goals and methods"

  attribute :short_name,
    type: String,
    desc: "The letter code designating this experiment",
    match: /^[A-Z]{2,5}$/,
    format_hint: "2-5 letters, all caps"

  collection :patient, display_name: "Patients", desc: "List of patients associated with this experiment"
end
