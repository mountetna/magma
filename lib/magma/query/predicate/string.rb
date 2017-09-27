class Magma
  class StringPredicate < Magma::ColumnPredicate
    verb nil do
      child String
    end

    verb "::matches", String do
      child TrueClass

      constraint do
        basic_constraint(@attribute_name, Regexp.new(@arguments[1]))
      end
    end

    verb "::equals", String do
      child TrueClass

      constraint do
        basic_constraint(@attribute_name, @arguments[1].to_f)
      end
    end

    verb "::in", Array do
      child TrueClass

      constraint do
        basic_constraint(@attribute_name, @arguments[1])
      end
    end
  end
end
