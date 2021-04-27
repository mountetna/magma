class Magma
  class StringPredicate < Magma::ColumnPredicate
    verb nil do
      child String
    end

    verb '::matches', String do
      child TrueClass

      constraint do
        basic_constraint(@column_name, Regexp.new(@arguments[1]))
      end
    end

    verb '::equals', String do
      child TrueClass

      constraint do
        basic_constraint(@column_name, @arguments[1])
      end
    end

    verb '::not', String do
      child TrueClass

      constraint do
        not_constraint(@column_name, @arguments[1])
      end
    end

    verb '::in', Array do
      child TrueClass

      constraint do
        basic_constraint(@column_name, @arguments[1])
      end
    end

    verb '::not', Array do
      child TrueClass

      constraint do
        not_constraint(@column_name, @arguments[1])
      end
    end

    verb [ '::<=', '::<', '::>=', '::>' ], String do
      child TrueClass

      constraint do
        and_constraint(
          [
            is_numeric_constraint(@column_name),
            double_cast_comparison_constraint(@column_name, @arguments[0], @arguments[1].to_f)
          ]
        )
      end
    end
  end
end
