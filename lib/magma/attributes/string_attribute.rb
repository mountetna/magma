class Magma
  class StringAttribute < Attribute
    def database_type
      String
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
    end
  end
end
