class Magma
  class ForeignKeyAttribute < Attribute
    include Magma::Link
    def column_name
      foreign_id
    end

    def json_for record
      record[@name]
    end

    def update record, link
      if link.nil?
        record[ foreign_id ] = nil
        return
      end

      link_model.update_or_create(link_model.identity => link) do |obj|
        record[ foreign_id ] = obj.id
      end
    end
    class Entry < Magma::BaseAttributeEntry
      def entry value
        return nil if value.nil?

        if value.is_a? Magma::TempId
          [ @attribute.foreign_id, value.real_id ]
        elsif @attribute.link_identity
          [ @attribute.foreign_id, @loader.identifier_id(@attribute.link_model, value) ]
        end
      end
    end
    class Validation < Magma::BaseAttributeValidation
      def validate(value)
        return if value.is_a?(Magma::TempId) || value.nil?
        if @attribute.link_identity
          @validator.validate(@attribute.link_model, @attribute.link_model.identity, value) do |error|
            yield error
          end
        end
      end
    end
  end
end
