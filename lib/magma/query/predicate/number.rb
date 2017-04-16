class Magma
  class NumberPredicate < Magma::ColumnPredicate
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
        invalid_argument! operand unless operand.respond_to? :to_f
        @operand = operand.to_f
        return terminal(TrueClass)
      when nil
        return terminal(Numeric)
      else
        invalid_argument! @argument
      end
    end
  end
end
