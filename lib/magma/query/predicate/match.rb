class Magma
  class MatchPredicate < Magma::ColumnPredicate
    verb '::type' do
      child String
    end

    verb '::value' do
      child String
    end

    verb nil do
      child String
    end

    def select
      [ Sequel[alias_name][@attribute_name].as(column_name) ]
    end
  end
end
