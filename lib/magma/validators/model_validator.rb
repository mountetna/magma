class Magma
  class ModelValidator
    def initialize(model, validator)
      @model = model
      @validator = validator
      @attribute_validatiors = {}
    end

    def validate(document)
      document.each do |att_name, value|

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

        validate_attribute(att_name, value) do |error|
          yield error
        end

      end
    end

    # For an attribute 'kind', select it's validator and and run the validation.
    def validate_attribute(att_name, value)
      attribute_validations(att_name).validate(value) do |error|
        yield error
      end
    end

    private

    # Return the memoized attribute validator for the attribute 'kind'.
    def attribute_validations(att_name)
      @attribute_validatiors[att_name] ||= @model.attributes[att_name].validation.new(@model, @model.attributes[att_name], @validator)
    end
  end
end