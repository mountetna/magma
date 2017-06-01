class Magma
  class DateTimePredicate < Magma::ColumnPredicate
    def constraint
      case @argument
      when "::<=", "::<", "::>", "::>=", "::="
        return [
          Magma::Question::Constraint.new(
            "? #{@argument.sub(/::/,'')} ?",
            :"#{alias_name}__#{@attribute_name}",
            @operand
          )
        ]
      end
      super
    end

    private

    def get_child
      case @argument
      when "::<=", "::<", "::>", "::>=", "::="
        operand = @predicates.shift
        invalid_argument! operand unless operand && operand.is_a?(String)
        @operand = DateTime.parse(operand)
        return terminal(TrueClass)
      when nil
        return terminal(DateTime)
      else
        invalid_argument! @argument
      end
    end
  end
end