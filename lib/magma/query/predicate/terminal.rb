class Magma
  class TerminalPredicate < Magma::Predicate
    def initialize value
      @terminal = value
    end

    def reduced_type
      @terminal
    end
  end
end
