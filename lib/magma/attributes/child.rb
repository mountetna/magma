class Magma
  class ChildAttribute < Attribute
    include Magma::Link
    def initialize(name, model, opts)
      model.one_to_one(name)
      super
    end

    def json_for record
      record[@name]
    end

    def update record, link
      link_model_name.update_or_create(link_model_name.identity => link) do |obj|
        obj[ self_id ] = record.id
      end
    end
    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value, &block)
        return if value.nil? || value.empty?
        link_validate(value, &block)
      end
    end
  end
end
