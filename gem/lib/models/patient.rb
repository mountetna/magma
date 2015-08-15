class Patient < Magma::Model
  identifier :ipi_number, match: IPI.match_patient_name, format_hint: "IPI<#{IPI::TUMOR_TYPES.keys.join('|')}><NNN>, e.g. IPICRC001", type: String, desc: "Unique id for patient (anonymized)"

  parent :experiment

  image :gross_specimen,
    desc: "Gross picture of the sample"

  link :clinical, column_type: :clinical_type_value

  attribute :notes,
    type: String,
    desc: "General notes about this sample"

  attribute :received_blood,
    type: TrueClass,
    desc: "Was blood received for this patient?"

  collection :sample

  document :flojo_file, display_name: "Flojo File",
    loader: :flowjo_xml_loader,
    desc: "WSP file from Flojo 10 containing all four stains for each sample for this patient."

  document :flow_pdf, display_name: "Flow cytometry PDF",
    desc: "PDF file summarizing populations for all four stains for each sample for this patient."

  def flowjo_xml_loader file
    fl = FlowJoLoader.new
    fl.load(flojo_file.file, self)
    fl.dispatch
  end

  def self.clinical_type_value document
    if document.respond_to? :experiment
      name = document.experiment.name
    else
      name = document[:experiment]
    end
    :"Clinical#{name.gsub(/\s/,'')}"
  end
end
