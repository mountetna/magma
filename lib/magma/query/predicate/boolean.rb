class Magma
  class BooleanPredicate < Magma::ColumnPredicate
    verb nil do
      child TrueClass
    end

    verb "::true" do
      child TrueClass
      constraint do
        Magma::Constraint.basic(true)
      end
    end

    verb "::false" do
      child TrueClass
      constraint do
        Magma::Constraint.basic(false)
      end
    end

    verb "::null" do
      child TrueClass
      constraint do
        Magma::Constraint.basic(nil)
      end
    end
  end
end
