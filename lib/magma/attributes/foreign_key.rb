class Magma
  class ForeignKeyAttribute < Attribute
    include Magma::Link
    def column_name
      foreign_id
    end

    def update(record_name, link)
      [ @name, link ]
    end

    def entry(value, loader)
      return nil if value.nil?

      if value.is_a? Magma::TempId
        [ foreign_id, value.real_id ]
      elsif link_identity
        [ foreign_id, loader.identifier_id(link_model, value) ]
      end
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value, &block)
        return if value.is_a?(Magma::TempId) || value.nil?
        link_validate(value,&block) if @attribute.link_identity
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
  end
end
