class Magma
  class DateTimePredicate < Magma::ColumnPredicate
    verb nil do
      child DateTime
    end

    verb [ '::<=', '::<', '::>=', '::>', '::=', '::!=' ], String do
      child TrueClass

      constraint do
        op, date = @arguments
        comparison_constraint(@column_name, op, DateTime.parse(date))
      end
    end

    verb [ '::nil' ] do
      child TrueClass

      constraint do
        null_constraint(@column_name)
      end
    end

    def extract table, identity
      table.first[column_name]&.iso8601
    end
  end
end
