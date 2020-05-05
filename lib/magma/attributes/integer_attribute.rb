class Magma
  class IntegerAttribute < Attribute
    def database_type
      Integer
    end

    class Validation < Magma::Validation::Attribute::RangeValidation
    end
  end
end
