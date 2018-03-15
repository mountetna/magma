class Magma
  class DateTimePredicate < Magma::ColumnPredicate
    verb nil do
      child DateTime
    end

    verb [ '::<=', '::<', '::>=', '::>', '::=', '::!=' ], DateTime do
      child TrueClass

      constraint do
        op, date = @arguments
        comparison_constraint(@attribute_name, op, date)
      end
    end
  end
end
