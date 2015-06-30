class Patient < Magma::Model
  identifier :ipi_number, match: IPI.match_patient_name, format_hint: "IPI<#{IPI::TUMOR_TYPES.keys.join('|')}><NNN>, e.g. IPICRC001", type: String, desc: "Unique id for patient (anonymized)"

  parent :experiment

  image :gross_specimen,
    desc: "Gross picture of the sample"

  attribute :notes,
    type: String,
    desc: "General notes about this sample"

  collection :sample

  document :flojo_file, display_name: "Flojo File",
    loader: :flowjo_xml_loader,
    desc: "XML file from Flojo containing all four stains for this sample."

  def flowjo_xml_loader file
    fl = FlowJoLoader.new
    fl.load flojo_file.file, self
  end
end
