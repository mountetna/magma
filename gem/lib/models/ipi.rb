class IPI
  class << self
    def patient_name
      # returns a regexp matching a valid patient name
      /^IPI#{tumor_types.source}[0-9]{3}/
    end

    def tumor_types
      /(?:CRC|MEL|HNSC|KID|BRC|LUNG|LIV)/
    end

    def cell_types
      /(?:treg|myel|teff|tumor|stroma)/
    end

    def sample_name
      /#{patient_name.source}\.[TN][0-9]/
    end

    def tube_name stain
      /#{sample_name.source}\.#{stain}/
    end

    def rna_seq_name
      /#{sample_name.source}\.rna\.#{cell_types.source}/
    end
  end
end
