class IPI
  class << self
    def patient_name
      # returns a regexp matching a valid patient name
      /^IPI#{tumor_types.source}[0-9]{3}/
    end

    def tumor_types
      /(?:CRC|MEL|HNSC|KID|BRC|LUNG|LIV)/
    end

    def sample_name
      /#{patient_name.source}\.[TN][0-9]/
    end

    def tube_name stain
      /#{sample_name.source}\.#{stain}/
    end

    def rna_seq_name stain
      /#{tube_name(stain).source}\.rna/
    end
  end
end
