class Magma
  class MatrixAttribute < Attribute
    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value, &block)
        return if value.nil? || value.empty?
        return if value.is_a?(Array) && value.all?{|v| v.is_a?(Numeric)}
        yield "#{value.to_json} is not an array of numbers"
      end
    end
  end
end
