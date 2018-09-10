class Magma
  class TerminalPredicate < Magma::Predicate
    def initialize question, value
      super(question)
      @terminal = value
    end

    verb nil do
    end

    def reduced_type
      @terminal
    end
  end
end
