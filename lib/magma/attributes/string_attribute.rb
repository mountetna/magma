class Magma
  class StringAttribute < Attribute
    def database_type
      String
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value)
        case validation_object
        when Regexp
          yield format_error(value) if !validation_object.match(value)
        when Array
          if !validation_object.map(&:to_s).include?(value)
            yield "On #{@attribute.name}, '#{value}' should be one of #{validation_object.join(", ")}."
          end
        end
      end
    end
  end
end
