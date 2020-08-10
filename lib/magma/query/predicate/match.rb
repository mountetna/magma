class Magma
  class MatchPredicate < Magma::ColumnPredicate
    verb '::type' do
      child String

      extract do |table, identity|
        table.first[column_name]['type']
      end
    end

    verb '::value' do
      child String

      extract do |table, identity|
        table.first[column_name]['value']
      end
    end

    verb nil do
      child String
    end

    def select
      [ Sequel[alias_name][@column_name].as(column_name) ]
    end
  end
end
