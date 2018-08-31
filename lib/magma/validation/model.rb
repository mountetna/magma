class Magma
  class Validation
    class Model
      class << self
        attr_reader :validations
        def inherited(subclass)
          @validations ||= []
          @validations << subclass
        end
      end

      def initialize(model, validator)
        @model = model
        @validator = validator
      end

      def validations
        @validations ||= self.class.validations.map do |validation_class|
          validation_class.new(@model, @validator)
        end
      end

      def validate(document, &block)
        validations.each do |validation|
          validation.validate(document, &block)
        end
      end
    end
  end
end

require_relative 'attribute'
require_relative 'identifier'

