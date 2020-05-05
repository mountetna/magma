class Magma
  class StringAttribute < Attribute
    def database_type
      String
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value)
        return unless @attribute.validation

        validation = @attribute.validation[:type].constantize.
          new(@attribute.validation[:value])

        case validation
        when Regexp
          yield format_error(value) if !validation.match(value)
        when Array
          if !validation.map(&:to_s).include?(value)
            yield "On #{@attribute.name}, '#{value}' should be one of #{validation.join(", ")}."
          end
        end
      end
    end
  end
end
