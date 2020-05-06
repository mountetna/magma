class Magma
  class FloatAttribute < Attribute
    def database_type
      Float
    end

    class Validation < Magma::Validation::Attribute::RangeValidation
    end

    private

    def validation_arguments
      @validation.values_at(:begin, :end, :exclude_end)
    end
  end
end
