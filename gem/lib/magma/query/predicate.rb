class Magma
  class Predicate
    attr_reader :argument

    def reduced_type
      if child_predicate.is_a?(Predicate)
        child_predicate.reduced_type
      else
        child_predicate
      end
    end

    def child_predicate
      @child_predicate
    end

    def join
      []
    end

    def constraint
      []
    end

    def select
      []
    end

    def extract table, identity
      table
    end

    private

    def invalid_argument! argument
      raise ArgumentError, "Expected an argument to #{self}" if argument.nil?
      raise ArgumentError, "#{argument} is not a valid argument to #{self}"
    end

    def terminal value
      raise ArgumentError, "Trailing arguments after terminal value!" unless @predicates.empty?
      Magma::TerminalPredicate.new(value)
    end
  end
end

require_relative 'predicate/model'
require_relative 'predicate/record'
require_relative 'predicate/column'
require_relative 'predicate/boolean'
require_relative 'predicate/date_time'
require_relative 'predicate/file'
require_relative 'predicate/number'
require_relative 'predicate/string'
require_relative 'predicate/terminal'
