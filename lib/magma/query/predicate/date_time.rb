class Magma
  class DateTimePredicate < Magma::ColumnPredicate
    verb nil do
      child DateTime
    end

    verb [ "::<=", "::<", "::>=", "::>", "::=" ], String do
      child TrueClass

      constraint do
        comparison_constraint(@attribute_name, @arguments[0], DateTime.parse(@arguments[1]))
      end
    end
  end
end
