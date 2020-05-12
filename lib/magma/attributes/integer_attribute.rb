class Magma
  class IntegerAttribute < Attribute
    def database_type
      Integer
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
    end
  end
end
