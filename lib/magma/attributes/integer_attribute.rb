class Magma
  class IntegerAttribute < Attribute
    def database_type
      Integer
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value)
        return unless @attribute.validation

        range = @attribute.validation[:type].constantize.new(
          @attribute.validation[:begin],
          @attribute.validation[:end],
          !!@attribute.validation[:exclude_end]
        )

        return if range.include?(value)

        yield "On #{@attribute.name}, #{value} should be between #{range.begin} and #{range.max}."
      end
    end
  end
end
