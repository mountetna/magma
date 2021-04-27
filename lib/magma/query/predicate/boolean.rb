class Magma
  class BooleanPredicate < Magma::ColumnPredicate
    verb nil do
      child TrueClass
    end

    verb '::true' do
      child TrueClass
      constraint do
        basic_constraint(@column_name, true)
      end
    end

    verb '::false' do
      child TrueClass
      constraint do
        basic_constraint(@column_name, false)
      end
    end

    verb '::untrue' do
      child TrueClass
      constraint do
        not_constraint(@column_name, true)
      end
    end

    verb '::nil' do
      child TrueClass
      constraint do
        null_constraint(@column_name)
      end
    end
  end
end
