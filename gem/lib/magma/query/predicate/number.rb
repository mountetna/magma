class Magma
  class NumberPredicate < Magma::ColumnPredicate
    def filter 
      filters = []
      case @argument
      when "::<=", "::<", "::>", "::>=", "::="
        filters.push Magma::Question::Filter.new(
          "? #{@argument.sub(/::/,'')} ?",
          "#{@model.table_name}__#{@attribute_name}",
          @operand
        )
      end

      filters.concat super
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
