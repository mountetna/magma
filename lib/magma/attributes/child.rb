class Magma
  class ChildAttribute < Attribute
    include Magma::Link
    def initialize(opts = {})
      super
      set_one_to_one if @magma_model
    end

    def magma_model=(new_magma_model)
      super
      set_one_to_one
    end

    def json_for record
      record[name]
    end

    def update_record record, link
      link_model.update_or_create(link_model.identity => link) do |obj|
        obj[ self_id ] = record.id
      end
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

    def set_one_to_one
      @magma_model.one_to_one(attribute_name.to_sym)
    end
  end
end
