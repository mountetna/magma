class IPI
  CELL_TYPES = [ :treg, :myeloid, :teff, :tumor, :stroma ]
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
      chain :sample_name, :rna, :cell_types
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

    def terminate match
      /#{match.source}$/
    end
  end
end
