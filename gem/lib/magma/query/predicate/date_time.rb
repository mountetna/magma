class Magma
  class DateTimePredicate < Magma::ColumnPredicate
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
