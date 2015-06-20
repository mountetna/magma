class Document < Magma::Model
  identifier :name, type: String, desc: "A unique name for this document"

  parent :project

  attribute :description, type: String, desc: "A brief description of the contents"

  document :file, desc: "Any kind of file or document"
end
