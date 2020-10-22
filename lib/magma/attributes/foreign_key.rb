class Magma
  class ForeignKeyAttribute < Attribute
    include Magma::Link

    # def revision_to_links(record_name, new_id)
    #   yield link_model, [ new_id ]
    # end

    def initial_column_name
      foreign_id
    end

    def entry(value, loader)
      # This allows you to orphan records.
      return [ foreign_id, nil ] if value.nil?

      if value.is_a? Magma::TempId
        [ foreign_id, value.real_id ]
      elsif link_identity && loader.identifier_exists?(link_model, value)
        [ foreign_id, loader.identifier_id(link_model, value) ]
      end
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value, &block)
        return if value.is_a?(Magma::TempId) || value.nil?
        link_validate(value,&block) if @attribute.link_identity
      end
    end
  end
end
