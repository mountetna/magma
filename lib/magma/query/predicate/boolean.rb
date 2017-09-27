class Magma
  class BooleanPredicate < Magma::ColumnPredicate
    def constraint
      case @argument
      when "::true"
        return [
          Magma::Constraint.new(
            Sequel.lit(
              Sequel.qualify(alias_name, @attribute_name) => true
            )
          )
        ]
      when "::false"
        return [
          Magma::Constraint.new(
            Sequel.lit(
              Sequel.qualify(alias_name, @attribute_name) => false
            )
          )
        ]
      end
      super
    end

    private

    def get_child
      case @argument
      when "::true"
      when "::false"
      when "::null"
        return terminal(TrueClass)
      when nil
        return terminal(TrueClass)
      else
        invalid_argument! @argument
      end
    end
  end
end
