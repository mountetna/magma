class Magma
  class MatchAttribute < Attribute
    def database_type
      :json
    end

    def entry(value, loader)
      [ column_name, value.to_json ]
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value, &block)
        return if value.nil? || value.empty?
        return if value.is_a?(Hash) && value.keys.sort == [ :type, :value ]
        yield "#{value.to_json} is not like { type, value }."
      end
    end
  end
end
