class Magma
  class FloatAttribute < Attribute
    def database_type
      Float
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
    end
  end
end
