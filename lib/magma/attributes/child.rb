class Magma
  class ChildAttribute < Attribute
    include Magma::Link

    def entry(value, loader)
      # The link model should be updated via
      #   revision_to_links, so we return nil
      #   here so the loader doesn't try
      #   to update a non-existent column.
      nil
    end

    def revision_to_links(record_name, new_id)
      yield link_model, [ new_id ]
    end

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
