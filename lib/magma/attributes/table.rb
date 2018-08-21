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

    def eager
      @name
    end

    def json_for(record)
      link = record[@name]
      link ? link.map(&:last) : nil
    end

    def txt_for(record)
      nil
    end

    def update(record, new_ids)
      nil
    end

    class Validator < Magma::AttributeValidator
      def validate(value)
        unless value.is_a?(Array)
          yield "#{value} is not an Array."
          return
        end
        return unless @attribute.link_identity
        value.each do |link|
          next if link.nil? || link.empty?
          args = [@attribute.link_model, @attribute.link_model.identity, link]
          @validator.validate(*args) do |error|
            yield error
          end
        end
      end
    end
  end
end
