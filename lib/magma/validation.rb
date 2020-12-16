require_relative 'validation/model'

class Magma
  class Validation
    def initialize
      @models = {}
    end

    def validate(model, document, record_name)
      model_validation(model).validate(document, record_name) do |error|
        yield error
      end
    end

    private

    def model_validation model
      @models[model] ||= Magma::Validation::Model.new(model, self)
    end
  end
end
