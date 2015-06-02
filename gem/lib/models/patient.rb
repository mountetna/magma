class Patient < Magma::Model
  identifier :ipi_number, match: IPI.patient_name, type: String, desc: "Unique id for patient (anonymized)"

  collection :sample

  document :flojo_file, display_name: "Flojo File",
    desc: "XML file from Flojo containing all four stains for this sample."
end
