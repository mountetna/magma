class Magma
  class Validation
    class Identifier < Magma::Validation::Model
      def validate(document)
        if @model.has_identifier? && !document[@model.identity]
          yield "Missing identifier for #{@model.name}"
        end
      end
    end
  end
end
