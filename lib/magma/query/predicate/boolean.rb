class Magma
  class BooleanPredicate < Magma::ColumnPredicate
    verb nil do
      child TrueClass
    end

    verb '::true' do
      child TrueClass
      constraint do
        basic_constraint(@attribute_name, true)
      end
    end

    verb '::false' do
      child TrueClass
      constraint do
        basic_constraint(@attribute_name, false)
      end
    end
  end
end
