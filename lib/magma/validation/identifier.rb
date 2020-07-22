class Magma
  class Validation
    class Identifier < Magma::Validation::Model
      def validate(document)
        if @model.has_identifier? && !document[@model.identity.attribute_name.to_sym]
          yield "Missing identifier for #{@model.name}"
        end
      end
    end
  end
end
