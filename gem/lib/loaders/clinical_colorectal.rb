require 'hash_table'

class ClinTable < HashTable
  types lymph_nodes_sampled: :float, lymph_nodes_positive: :int
  index :case_no
  class Record < HashTable::Row
    def is_ipi?
      case_no && case_no =~ /IPI/
    end

    def ipi_number
      num = case_no.split(/\s/).last
      "IPICRC#{num[1..-1]}"
    end

    def clinical_name
      ipi_number + ".clin"
    end

    def age_at_diagnosis
      ((date_for(:diagnosis_date) - date_for(:case_patient_birth_date)) / 365.0).round(0)
    end

    def race_ethnicity
      [ case_patient_race, case_patient_ethnicity ].compact.join(" / ")
    end

    def lymph_fraction
      lymph_nodes_positive / [ 1, lymph_nodes_sampled || 1 ].max
    end

    def tnm
      t = colorectal_tnm_staging__t.split(/\s/).first
      n = colorectal_tnm_staging__n.split(/\s/).first
      m = colorectal_tnm_staging__m.split(/\s/).first
      "#{t}#{n}#{m}"
    end

    def date_for date_column
      month, day, year = (send(date_column) || '').split(%r!/!)
      Date.new *[ year, month, day ].compact.map(&:to_i)
    end

    def msi_status
      (!msimmr || msimmr.empty? || msimmr == "Not done") ? nil : msimmr
    end

    def oncogene_status
      status = [ 
        (kras !~ /(Not done|No mutation)/ ? "KRAS.#{kras}" : nil),
        (braf !~ /(Not done|No mutation)/ ? "BRAF.#{braf}" : nil),
      ].compact.join(",")
    end
  end
end

class ClinicalColorectalLoader < Magma::Loader
  def load file
    # The flow jo file collects all of the stain gatings and counts for a set of tumor samples
    # from a single patient.
    @clin = ClinTable.new.parse file
  end

  def dispatch
    create_clinical_records
    update_patient_records
  end

  private
  def create_clinical_records
    @clin.index[:case_no].entries.each do |case_no|
      records = @clin.index[:case_no][case_no]
      record = records.first
      next unless record.is_ipi?
      push_record ClinicalColorectal, {
        clinical_name: record.clinical_name,
        age_at_diagnosis: record.age_at_diagnosis,
        sex: record.case_patient_gender,
        race_ethnicity: record.race_ethnicity,
        stage: record.tnm,
        grade: record.primary_tumor_grade,
        #outcomes, type: String, desc: "Last alive date/expired date/response to therapies, RECIST response, etc."
        #history, type: String, desc: "History of disease"
        site: record.disease_site,
        histology: record.primary_tumor_histology,
        lymph_fraction: record.lymph_fraction,
        msi_status: record.msi_status,
        oncogene_status: record.oncogene_status
      }
    end
    dispatch_record_set
  end

  def update_patient_records
    @clin.index[:case_no].entries.each do |case_no|
      records = @clin.index[:case_no][case_no]
      record = records.first
      next unless record.is_ipi?
      if patient = Patient[ipi_number: record.ipi_number]
        push_record Patient, {
          ipi_number: record.ipi_number,
          clinical: record.clinical_name
        }
      end
    end
    dispatch_record_set
  end
end
