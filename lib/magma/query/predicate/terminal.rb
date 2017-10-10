class Magma
  class TerminalPredicate < Magma::Predicate
    def initialize value
      @terminal = value
    end

    verb nil do
    end

    def reduced_type
      @terminal
    end
  end
end
