class Magma
  class DateTimeAttribute < Attribute
    def database_type
      DateTime
    end

    class Validation < Magma::Validation::Attribute::RangeValidation
    end

    private

    def validation_arguments
      @validation.values_at(:begin, :end, :exclude_end)
    end
  end
end
