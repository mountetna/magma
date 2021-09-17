class Magma
  class Validation
    class Attribute < Magma::Validation::Model
      def initialize(model, validator)
        super
        @attribute_validations = {}
      end

      def validate(record_name, document)
        document.each do |att_name,value|
          next if att_name == :id || att_name == :$identifier
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
        # Also validate the record name separately, if it
        #   is not included in the document.
        attribute_validations(identifier_attribute_name).validate(record_name) do |error|
          yield error
        end unless document.key?(identifier_attribute_name)
      end

      private

      def identifier_attribute_name
        @model.attributes.values.select do |attribute|
          attribute.is_a?(Magma::IdentifierAttribute)
        end.first.name.to_sym
      end

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
          return if validation_object.validate(value)
          yield validation_object.error_message(@attribute.name, value, @attribute.format_hint)
        end

        def validation_object
          @attribute.validation_object
        end

        private

        def format_error(value)
          if link_attribute.format_hint
            "On #{@attribute.name}, '#{value}' should be like '#{link_attribute.format_hint}'."
          else
            "On #{@attribute.name}, '#{value}' is improperly formatted."
          end
        end

        def link_attribute
          @attribute.link_model.identity
        end

        def link_validate(value, &block)
          @validator.validate(@attribute.link_model, value, link_attribute.attribute_name.to_sym => value) do |error|
            if error =~ /format/
              yield format_error(value)
            else
              yield error
            end
          end
        end
      end
    end
  end
end
