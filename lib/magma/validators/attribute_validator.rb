class Magma
  class AttributeValidator
    def initialize(model, attribute, validator)
      @model = model
      @attribute = attribute
      @validator = validator
    end

    def validate(value)
      # To be overridden in the attribute classes.
    end
  end
end
