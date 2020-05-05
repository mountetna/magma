class Magma
  class StringAttribute < Attribute
    def database_type
      String
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value)
        case validation
        when Regexp
          yield format_error(value) if !validation.match(value)
        when Array
          if !validation.map(&:to_s).include?(value)
            yield "On #{@attribute.name}, '#{value}' should be one of #{validation.join(", ")}."
          end
        end
      end

      private

      # memoize match to reuse across validations
      def validation
        @validation ||= @attribute.validation.is_a?(Proc) ?
          @attribute.validation.call : @attribute.validation
      end
    end
  end
end
