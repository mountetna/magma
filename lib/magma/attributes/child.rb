class Magma
  class ChildAttribute < Attribute
    include Magma::Link
    def query_to_payload(value)
      value
    end

    def missing_column?
      false
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value, &block)
        return if value.nil? || value.empty?
        link_validate(value, &block)
      end
    end

    private

    def after_magma_model_set
      @magma_model.one_to_one(attribute_name.to_sym)
    end
  end
end
