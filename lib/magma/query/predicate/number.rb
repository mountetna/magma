class Magma
  class NumberPredicate < Magma::ColumnPredicate
    verb nil do
      child Numeric
    end

    verb [ '::<=', '::<', '::>=', '::>', '::=', '::!=' ], Numeric do
      child TrueClass

      constraint do
        comparison_constraint(@column_name, @arguments[0], @arguments[1].to_f)
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

    verb [ '::nil' ] do
      child TrueClass

      constraint do
        null_constraint(@column_name)
      end
    end
  end
end
