class IPI
  CELL_TYPES = [ :treg, :myeloid, :teff, :tumor, :stroma, :tcell,
                 :cd45neg, :epcam, :immune, :live, :other ]
  class << self
    def patient_name
      # returns a regexp matching a valid patient name
      /^IPI#{tumor_types.source}[0-9]{3}/
    end

    def tumor_types
      match_array tumor_short_names
    end

    def tumor_short_names
      Experiment.dataset.order
        .distinct
        .exclude(short_name:nil)
        .select_map(:short_name)
    end

    def cell_types
      match_array IPI::CELL_TYPES
    end

    def clinical_name
      chain :patient_name, :clin
    end

    def sample_name
      chain :patient_name, /[TN][0-9]/
    end

    def tube_name stain
      chain :sample_name, stain
    end

    def rna_seq_name
      match_array(
        [
          chain(:sample_name, :rna, /\w+/),
        /^Control_(UHR|Jurkat).Plate\d+$/
        ]
      )
    end

    def match sym, *args
      /#{ send(sym, *args).source }$/
    end

    private
    def chain *regs
      Regexp.new(regs.map do |reg|
        case reg
        when Symbol
          if respond_to? reg
            re = send reg
            re.source
          else
            reg.to_s
          end
        when Regexp
          reg.source
        when String
          reg
        end
      end.join('\.'))
    end
    def match_array ary
      /(?:#{ary.join('|')})/
    end
  end
end
