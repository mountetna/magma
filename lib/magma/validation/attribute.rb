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
        validation_class = :"#{att.class.to_s.split('::').last}Validation"
        Magma::Validation::Attribute.const_defined?(validation_class) ?
          Magma::Validation::Attribute.const_get(validation_class) :
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
      end

      class AttributeValidation < BaseAttributeValidation
        def validate(value)
          case match
          when Regexp
            yield format_error(value) if !match.match(value)
          when Array
            if !match.map(&:to_s).include?(value)
              yield "On #{@attribute.name}, '#{value}' should be one of #{match.join(", ")}."
            end
          end
        end

        private

        def match
          @match ||= @attribute.match.is_a?(Proc) ? @attribute.match.call : @attribute.match
        end

        def format_error(value)
          if @attribute.format_hint
            "On #{@attribute.name}, '#{value}' should be like '#{@attribute.format_hint}'."
          else
            "On #{@attribute.name}, '#{value}' is improperly formatted."
          end
        end
      end

      class ChildValidation < BaseAttributeValidation
        def validate(value)
          return if value.nil? || value.empty?
          @validator.validate(@attribute.link_model, @attribute.link_model.identity => value) do |error|
            yield error
          end
        end
      end
      class ForiegnKeyValidation < BaseAttributeValidation
        def validate(value)
          return if value.is_a?(Magma::TempId) || value.nil?
          if @attribute.link_identity
            @validator.validate(@attribute.link_model, @attribute.link_model.identity => value) do |error|
              yield error
            end
          end
        end
      end
      class CollectionValidation < BaseAttributeValidation
        def validate(value)
          unless value.is_a?(Array)
            yield "#{value} is not an Array."
            return
          end
          value.each do |link|
            next unless link
            @validator.validate(@attribute.link_model, @attribute.link_model.identity => link) do |error|
              yield error
            end
          end
        end
      end
      class TableValidation < CollectionValidation; end
    end
  end
end
