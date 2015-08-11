#Clinical data will be collected in a secure OnCore URM database. We collect
#additional data about the specimens in an OnCore BSM database and store consent
#info there; consents themselves are scanned into the APEX electronic medical
#record.

module Clinical
  def self.included base
    base.identifier :clinical_name, match: IPI.match_clinical_name, format_hint: "IPICRC001.clin", type: String
    base.one_to_many :patients, :as => :clinical
    base.attribute :age_at_diagnosis, type: Integer, display_name: "Age at diagnosis"
    base.attribute :sex, type: String, display_name: "Sex"
    base.attribute :race_ethnicity , type: String, display_name: "Race/ethnicity"
    base.attribute :treatment, type: String, 
      desc: "Treatment history (previous chemo, immunotherapy, targeted therapy, radiation)"
    base.attribute :stage, type: String, desc: "Stage of disease"
    base.attribute :grade, type: String, display_name: "Primary tumor grade"
    base.attribute :outcomes, type: String, desc: "Last alive date/expired date/response to therapies, RECIST response, etc."
    base.attribute :history, type: String, desc: "History of disease"
  end
  def patient
    patients.first
  end
end

class ClinicalColorectal < Magma::Model
  include Clinical
  attribute :site , type: String, desc: "Location within the colon/rectum (*of particular clinical interest)"
  attribute :histology, type: String, desc:  "Tumor histology (e.g. adenocarcinoma, mucinous features present)  "
  attribute :lymph_fraction, type: Float, desc: "Number of lymph nodes sampled/ number lymph nodes containing cancer "
  attribute :msi_status, type: String, desc: "Microsatellite instability status"
  attribute :oncogene_status, type: String, desc: "KRAS or BRAF status (or other oncogene or tumor suppressor status, if known)"
end

class ClinicalMelanoma < Magma::Model
  include Clinical
  attribute :site, type: String, desc: "Primary site (cutaneous, mucosal, uveal, unknown)"
  attribute :ecog, type: String, desc: "ECOG"
  attribute :histology, type: String, desc: "Histologic subtype (superficial spreading, nodular, lentigo maligna, acral lentiginous, desmoplastic, nevoid, other)"
  attribute :oncogene_status, type: String, desc: "BRAF status (or other oncogene if known)"
  attribute :ldh, type: String, desc: "LDH"
  attribute :metastatic_sites, type: String, desc: "Metastatic sites (brain, liver, lung)"
  attribute :biopsy, type: String, desc: "Biopsy info (date, site)"
end

class ClinicalHnsc < Magma::Model
  include Clinical
  attribute :site, type: String, desc: "Primary site (oral, oropharyngeal, nasopharyngeal, hypopharyngeal, laryngeal, sinus, salivary gland) "
  attribute :hpv, type: TrueClass, desc: "HPV associated"
  attribute :biopsy, type: String, desc: "Biopsy info, (date, site)"
end


class ClinicalBreast < Magma::Model
  include Clinical
end
