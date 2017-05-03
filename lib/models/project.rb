class Project < Magma::Model
  identifier :name, type: String, desc: "Name for this project"

  attribute :description, type: String

  attribute :whats_new, type: String, display_name: "What's New"

  attribute :faq, type: String, display_name: "FAQ"

  collection :experiment

  collection :document

  collection :rna_seq_plate
end
