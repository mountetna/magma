#Clinical data will be collected in a secure OnCore URM database. We collect
#additional data about the specimens in an OnCore BSM database and store consent
#info there; consents themselves are scanned into the APEX electronic medical
#record.

class Clinical < Magma::Model
  collection :patient

  identifier :clinical_name, match: Proc.new { IPI.match_clinical_name }, format_hint: "IPICRC001.clin", type: String

  attribute :race_ethnicity , type: String, display_name: "Race/ethnicity"
  attribute :sex, type: String, display_name: "Sex"
  attribute :age_at_diagnosis, type: Integer, display_name: "Age at diagnosis"
  attribute :stage, type: String, desc: "Stage of disease"
  attribute :grade, type: String, display_name: "Primary tumor grade"
  attribute :history, type: String, desc: "History of disease"

  table :parameter
  table :treatment
  table :outcome
end

class Parameter < Magma::Model
  parent :clinical
  attribute :name, type: String, desc: "Parameter name"
  attribute :description, type: String
  attribute :type, type: String
  attribute :value, type: String
end

class Outcome < Magma::Model
  parent :clinical
  attribute :name, type: String, desc: "Outcome class"
  attribute :value, type: String
end

class Treatment < Magma::Model
  parent :clinical
  attribute :type, type: String, desc: "Therapy type"
  attribute :regimen, type: String, desc: "Therapy regimen (drug name, other procedure name)"
  attribute :start, type: DateTime, desc: "Start date of treatment"
  attribute :stop, type: DateTime, desc: "Stop date of treatment"
end
