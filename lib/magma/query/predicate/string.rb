class Magma
  class StringPredicate < Magma::ColumnPredicate
    def constraint 
      case @argument
      when "::matches", "::equals", "::in"
        return [
          Magma::Constraint.new(
            Sequel.qualify(alias_name, @attribute_name) => @operand
          )
        ]
      end

      super
    end

    def to_hash
      super.merge(
        operand: @operand
      )
    end

    private

    def get_child
      case @argument
      when "::matches"
        operand = @query_args.shift
        invalid_argument! operand unless operand && operand.is_a?(String)
        @operand = Regexp.new(operand)
        return terminal(TrueClass)
      when "::equals"
        @operand = @query_args.shift
        invalid_argument! @operand unless @operand && @operand.is_a?(String)
        return terminal(TrueClass)
      when "::in"
        @operand = @query_args.shift
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
