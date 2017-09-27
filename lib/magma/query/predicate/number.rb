class Magma
  class NumberPredicate < Magma::ColumnPredicate
    def constraint 
      case @argument
      when "::<=", "::<", "::>", "::>=", "::="
        return [
          Magma::Constraint.new(
            Sequel.lit(
              "? #{@argument.sub(/::/,'')} ?",
              Sequel.qualify(alias_name, @attribute_name),
              @operand
            )
          )
        ]
      when "::in"
        return [
          Magma::Constraint.new(
            Sequel.qualify(alias_name, @attribute_name) => @operand
          )
        ]
      end
      super
    end

    private

    def get_child
      case @argument
      when "::<=", "::<", "::>", "::>=", "::="
        operand = @query_args.shift
        invalid_argument! operand unless operand.respond_to? :to_f
        @operand = operand.to_f
        return terminal(TrueClass)
      when "::in"
        @operand = @query_args.shift
        invalid_argument! @operand unless @operand && @operand.is_a?(Array)
        return terminal(TrueClass)
      when nil
        return terminal(Numeric)
      else
        invalid_argument! @argument
      end
    end
  end
end
