class Magma
  class StringAttribute < Attribute
    def database_type
      String
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value)
        case match
        when Regexp
          yield format_error(value) if !match.match(value)
        when Array
          if !match.map(&:to_s).include?(value)
            yield "On #{@attribute.name}, '#{value}' should be one of #{match.join(", ")}."
          end
        end
      end

      private

      # memoize match to reuse across validations
      def match
        @match ||= @attribute.match.is_a?(Proc) ? @attribute.match.call : @attribute.match
      end
    end
  end
end
