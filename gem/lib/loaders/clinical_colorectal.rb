require 'spreadsheet'

class ClinSpreadsheet
  class Row
    def initialize clin, row
      @row = row
      @clin = clin
    end

    def [](col)
      get_col col
    end

    def get_col col
      if col.is_a? Fixnum
        @row[col]
      else
        @row[@clin.column_for col]
      end
    end

    def is_ipi?
      get_col("Case No") =~ /IPI/
    end

    def ipi_number
      num = get_col("Case No").split(/\s/).last
      "IPICRC#{num[1..-1]}"
    end

    def clinical_name
      ipi_number + ".clin"
    end

    def tnm
      terms = [
        get_col("Colorectal TNM Staging - T"),
        get_col("Colorectal TNM Staging - N"), 
        get_col("Colorectal TNM Staging - M"),
      ]
      return terms.join("\t") unless terms.any?{|term| term.nil? || term.empty? }
    end
  end
  def initialize file
    @sheet = Spreadsheet.open file
  end

  def worksheet
    @worksheet ||= @sheet.worksheet(0)
  end

  def header
    @header ||= worksheet.rows[0].to_a
  end

  def column_for name
    header_set[name] ? header_set[name] : nil
  end

  def rows
    @rows ||= worksheet.rows[ 1..worksheet.rows.size-1 ].map do |row|
      ClinSpreadsheet::Row.new(self, row)
    end
  end

  def by_patient
    @by_patient = rows.group_by do |r|
      r["Case No"]
    end
  end

  private
  def header_set
    @header_set ||= Hash[header.zip header.size.times.to_a]
  end
end

class ClinicalColorectalLoader < Magma::Loader
  def load file
    # The flow jo file collects all of the stain gatings and counts for a set of tumor samples
    # from a single patient.
    @clin = ClinSpreadsheet.new file
  end

  def dispatch
    create_clinical_records
    update_patient_records
  end

  private
  ATTRIBUTES = [
    # This gets parsed into an IPI number anyway.
    # "Case No"
    {
      key: "Case Institution",
      name: "Institution",
      type: String
    },
    {
      key: "Patient Age",
      name: "Age",
      type: Integer
    },
    {
      key: "Case Patient Gender",
      name: "Gender",
      type: String
    },
    {
      key: "Diagnosis Date",
      type: Date,
    },
    {
      key: "Disease Site",
      type: String
    },
    {
      key: "Primary Tumor Histology",
      type: String
    },
    {
      key: "Primary Tumor Grade",
      type: String
    },
    {
      key: "Colorectal TNM Staging - T",
      type: String
    },
    {
      key: "Colorectal TNM Staging - M",
      type: String
    },
    {
      key: "Colorectal TNM Staging - N",
      type: String
    },
    {
      key: "Lymph nodes sampled",
      type: Integer
    },
    {
      key: "Lymph nodes positive",
      type: Integer
    },
    {
      key: "Rectal Cancer Staging Descriptor",
      type: String
    },
    {
      key: "Comments (if Other, Specify)",
      name: "Comments",
      type: String
    },
    {
      key: "KRAS",
      type: String
    },
    {
      key: "BRAF",
      type: String
    },
    {
      key: "MSI/MMR",
      type: String
    },

    # Ignore these, they are redundant with the actual resutls being present or absent
    # "Clinical Mutation Panel Testing Present for tumor? (Y/N)",
    # "Clinical Mutation Panel Testing Present for germline (Y/N)",
    #
    # Ignore treatment information, captured in a separate table
    # "Therapy Type",
    # "Treatment Regimen",
    # "Start Date",
    # "Stop Date",
    {
      key: "Date IPI collected.",
      name: "Date of IPI collection",
      type: Date
    },
    {
      key: "Site IPI collected from.",
      name: "Site of IPI collection",
      type: String
    },
    {
      key: "Clinical Mutation Panel Testing Results (Tumor)",
      type: String
    },
    {
      key: "Clinical Mutation Panel Testing Results (Germiline)",
      name: "Clinical Mutation Panel Testing Results (Germline)",
      type: String
    }

    # We can glean this from the treatment history, which is much better-formed
    # "Treatment with chemo or XRT before IPI collection (Yes/No =1/0)",
    
    # Ignore this hideous thing
    # "Other information pertinent to IPI (ie: if concurrent malignancy or treatment, or if multiple sites of biopsies were taken, or if known genetic syndrome or striking family history)"
  ]

  def create_clinical_records
    @clin.by_patient.each do |patient, records|
      record = records.first
      next unless record.is_ipi?
      push_record Clinical, {
        clinical_name: record.clinical_name,
        #race_ethnicity: record.race_ethnicity,
        sex: record["Case Patient Gender"],
        age_at_diagnosis: record["Patient Age"],
        stage: record.tnm,
        grade: record["Primary Tumor Grade"],
        temp_id: temp_id(record)
      }
      records.each do |treat|
        push_record Treatment, {
          temp_id: temp_id([ :treat, treat ]),
          clinical: temp_id(record),
          type: treat["Therapy Type"],
          regimen: treat["Treatment Regimen"],
          start: treat["Start Date"],
          stop: treat["Stop Date"]
        }
      end
      ATTRIBUTES.each do |att|
        value = record[ att[:key] ]
        next unless value
        push_record Parameter, {
          temp_id: temp_id([ att, record ]),
          clinical: temp_id(record),
          name: att[:name] || att[:key],
          type: att[:type].name,
          value: value
        }
      end
    end
    dispatch_record_set
  end

  def update_patient_records
    @clin.by_patient.each do |patient, records|
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
