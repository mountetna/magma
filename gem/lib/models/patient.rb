class Patient < Magma::Model
  identifier :ipi_number, match: IPI.patient_name, type: String, desc: "Unique id for patient (anonymized)"

  parent :experiment

  collection :sample

  document :flojo_file, display_name: "Flojo File",
    loader: :flowjo_xml_loader,
    desc: "XML file from Flojo containing all four stains for this sample."

  def flowjo_xml_loader file
    fl = FlowJoLoader.new
    fl.load flojo_file.file, self
  end
end
