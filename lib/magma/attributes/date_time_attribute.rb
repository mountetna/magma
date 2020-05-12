class Magma
  class DateTimeAttribute < Attribute
    def database_type
      DateTime
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
    end
  end
end
