class IPI
  CELL_TYPES = [ :treg, :myeloid, :teff, :tumor, :stroma ]
  TUMOR_TYPES = { CRC: :Colorectal, MEL: :Melanoma, HNSC: :"Head and Neck", KID: :Kidney, BRC: :Breast, LUNG: :Lung, LIV: :Liver, BLAD: :Bladder, PROS: :Prostate }
  class << self
    def patient_name
      # returns a regexp matching a valid patient name
      /^IPI#{tumor_types.source}[0-9]{3}/
    end


    def tumor_types
      match_array IPI::TUMOR_TYPES.keys
    end

    def cell_types
      match_array IPI::CELL_TYPES
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

    def method_missing sym, *args, &block
      sym.to_s.match(/^match_(?<prop>.*)$/) do |m|
        if respond_to?(m[:prop])
          return terminate(send(m[:prop], *args))
        end
      end
      super
    end

    private
    def match_array ary
      /(?:#{ary.join('|')})/
    end

    def terminate match
      /#{match.source}$/
    end
  end
end
