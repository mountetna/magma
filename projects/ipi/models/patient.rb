class Patient < Magma::Model
  identifier :ipi_number, 
    type: String, 
    match: Proc.new { IPI.match(:patient_name) }, 
    format_hint: "IPI<short_name><NNN>, e.g. IPICRC001",
    desc: "Unique id for patient (anonymized)"

  parent :experiment

  image :gross_specimen,
    desc: "Gross picture of the sample"

  link :clinical

  attribute :notes,
    type: String,
    desc: "General notes about this sample"

  attribute :received_blood,
    type: TrueClass,
    desc: "Was blood received for this patient?"

  attribute :ice_time, 
    type: Float,
    desc: "Time that the sample spent on ice before digestion (hours)"

  attribute :physician, 
    type: String, 
    desc: "Contact person who provided access to the sample"

  attribute :date_of_digest, 
    type: DateTime, 
    desc: "Date when digest was done"

  attribute :date_of_extraction, 
    display_name: "Date of Surgery",
    type: DateTime, 
    desc: "Date when sample was taken out of patient"

  attribute :ffpe_frozen,
    display_name: "FFPE/Frozen",
    type: TrueClass,
    desc: "Whether sample was taken from FFPE"

  attribute :processor,
    type: String,
    desc: "Who received and processed the sample"

  collection :sample

  document :flojo_file, display_name: "Flojo File",
    loader: :flowjo_xml_loader,
    desc: "WSP file from Flojo 10 containing all four stains for each sample for this patient."

  link :reference_patient, link_model: :patient

  attribute :stain_version,
    type: String,
    desc: "Version of the stain panel used for processing."

  attribute :sop_version,
    type: String,
    match: [ "SOP1", "SOP2", "SOP3" ],
    desc: "Version of SOP used for processing."

  table :stain_panel,
    desc: "List of stain panels used to analyze this patient."

  document :flow_pdf, display_name: "Flow cytometry PDF",
    desc: "PDF file summarizing populations for all four stains for each sample for this patient."

  def flowjo_xml_loader
    fl = FlowJoLoader.new
    fl.load(self.flojo_file.file, self)
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
