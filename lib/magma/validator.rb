# See /lib/magma/validators/README.md

class Magma
  class Validator
    def initialize
      @model_validators = {}
      @model_matchers = {}
    end

    # If a default attribute has a complex type (such as a collection or table)
    # then those sub items also have their own model and type. In this situation
    # the attribute will have an overriding Magma::AttributeValidator. This will
    # break out the individual items and then call this function on each sub
    # item.
    def validate(model, att_name, value)
      model_validator(model).validate_attribute(att_name, value) do |error|
        yield error
      end
    end

    # If there is not a validator set on the model then use the default
    # ModelValidator
    def model_validator(model = nil)
      if model.validator == nil

        # Build a default ModelValidator.
        @model_validators[model] ||= Magma::ModelValidator.new(model, self)
      else

        # Pull the validator that was defined on the model.
        @model_validators[model] ||= model.validator.new(model, self)
      end
      return @model_validators[model]
    end

    # A 'dictionary' is a special type of Sequel model/DB that is used for
    # validation. See '/projects/dictionary'.
    def model_matcher(dictionary = nil)
      return nil if dictionary == nil
      @model_matchers[dictionary] ||= Magma::Matcher.new(dictionary)
    end
  end
end

require_relative './validators/attribute_validator'
require_relative './validators/model_validator'
require_relative './validators/matcher'
