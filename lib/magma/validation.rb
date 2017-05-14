class Magma
  class Validator
    def initialize
      @models = {}
    end

    def validate(model, att_name, value)
      model_validation(model).validate_attribute(att_name, value) do |error|
        yield error
      end
    end

    def model_validation model
      @models[model] ||= Magma::ModelValidation.new(model, self)
    end
  end

  class ModelValidation
    def initialize(model, validator)
      @model = model
      @validator = validator
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
        validate_attribute(att_name,value) do |error|
          yield error
        end
      end
    end

    def validate_attribute(att_name,value)
      attribute_validations(att_name).validate(value) do |error|
        yield error
      end
    end

    private

    def attribute_validations(att_name)
      @attribute_validations[att_name] ||= @model.attributes[att_name].validation.new(
        @model, @model.attributes[att_name], @validator
      )
    end
  end
  class BaseAttributeValidation
    def initialize(model, attribute,validator)
      @model = model
      @attribute = attribute
      @validator = validator
    end

    def validate(value)
      # do nothing
    end
  end
end
