class Magma
  class Validation
    class Attribute < Magma::Validation::Model
      def initialize(model, validator)
        super
        @attribute_validations = {}
      end

      def validate(document)
        document.each do |att_name,value|
          if att_name == :temp_id
            unless value.is_a? Magma::TempId
              yield "temp_id should be of class Magma::TempId"
            end
            next
          end
          if !@model.has_attribute?(att_name)
            yield "#{@model.name} has no attribute '#{att_name}'"
            next
          end
          attribute_validations(att_name).validate(value) do |error|
            yield error
          end
        end
      end

      private

      def attribute_validations(att_name)
        @attribute_validations[att_name] ||= validation(@model.attributes[att_name]).new(
          @model, @validator, @model.attributes[att_name]
        )
      end

      def validation(att)
        att.class.const_defined?(:Validation) ?
          att.class.const_get(:Validation) :
          Magma::Validation::Attribute::BaseAttributeValidation
      end

      class BaseAttributeValidation
        def initialize(model, validator, attribute)
          @model = model
          @validator = validator
          @attribute = attribute
        end

        def validate(value)
          # do nothing
        end

        private

        def format_error(value)
          if @attribute.format_hint
            "On #{@attribute.name}, '#{value}' should be like '#{@attribute.format_hint}'."
          else
            "On #{@attribute.name}, '#{value}' is improperly formatted."
          end
        end

        def link_validate(value, &block)
          @validator.validate(@attribute.link_model, @attribute.link_model.identity => value) do |error|
            yield format_error(value)
          end
        end
      end
    end
  end
end
