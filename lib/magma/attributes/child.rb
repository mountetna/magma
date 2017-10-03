class Magma
  class ChildAttribute < Attribute
    include Magma::Link
    def schema_ok?
      true
    end

    def schema_unchanged? 
      true
    end

    def needs_column?
      nil
    end

    def json_for record
      record[@name]
    end

    def eager
      @name
    end

    def update record, link
      link_model.update_or_create(link_model.identity => link) do |obj|
        obj[ self_id ] = record.id
      end
    end
    class Validation < Magma::BaseAttributeValidation
      def validate(value)
        return if value.nil? || value.empty?
        @validator.validate(@attribute.link_model, @attribute.link_model.identity, value) do |error|
          yield error
        end
      end
    end
  end
end
