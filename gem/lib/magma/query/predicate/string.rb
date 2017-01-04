class Magma
  class StringPredicate < Magma::ColumnPredicate
    def filter 
      filters = []
      case @argument
      when "::matches", "::equals", "::in"
        filters.push Magma::Question::Filter.new(
          :"#{@model.table_name}__#{@attribute_name}" => @operand
        )
      end

      filters.concat super
    end

    private

    def get_child
      case @argument
      when "::matches"
        operand = @predicates.shift
        invalid_argument! operand unless operand && operand.is_a?(String)
        @operand = Regexp.new(operand)
        return terminal(TrueClass)
      when "::equals"
        @operand = @predicates.shift
        invalid_argument! @operand unless @operand && @operand.is_a?(String)
        return terminal(TrueClass)
      when "::in"
        @operand = @predicates.shift
        invalid_argument! @operand unless @operand && @operand.is_a?(Array)
        return terminal(TrueClass)
      when nil
        return terminal(String)
      else
        invalid_argument! @argument
      end
    end
  end
end
