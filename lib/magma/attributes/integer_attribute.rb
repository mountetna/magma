class Magma
  class IntegerAttribute < Attribute
    def database_type
      Integer
    end

    class Validation < Magma::Validation::Attribute::RangeValidation
    end

    private

    def validation_arguments
      @validation.values_at(:begin, :end, :exclude_end)
    end
  end
end
