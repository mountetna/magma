class Magma
  class TableAttribute < Attribute
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

    def tab_column?
      nil
    end

    def json_for record
      table = record.send(@name)
      table.map &:identifier
    end

    def txt_for record
      nil
    end

    def eager
      @name
    end

    def update record, new_value
    end

    class Validation < Magma::BaseAttributeValidation
      def validate value
        unless value.is_a?(Array)
          yield "#{value} is not an Array."
          return
        end
        return unless @attribute.link_identity
        value.each do |link|
          next if link.nil? || link.empty?
          @validator.validate(@attribute.link_model,@attribute.link_model.identity,link) do |error|
            yield error
          end
        end
      end
    end
  end
end
