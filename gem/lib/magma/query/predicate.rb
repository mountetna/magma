class Magma
  class Predicate
    attr_reader :child_predicate, :argument

    def reduced_type
      if @child_predicate.is_a?(Predicate)
        @child_predicate.reduced_type
      else
        @child_predicate
      end
    end

    def join
      predicate_collect :join
    end

    def filter
      predicate_collect :filter
    end

    def select
      predicate_collect :select
    end

    def extract table, identity
      @child_predicate.is_a?(Predicate) ? @child_predicate.extract(table, identity) : table
    end

    private

    def predicate_collect type
      @child_predicate.is_a?(Predicate) ? @child_predicate.send(type) : []
    end

    def invalid_argument! argument
      raise ArgumentError, "Expected an argument to #{self}" if argument.nil?
      raise ArgumentError, "#{argument} is not a valid argument to #{self}"
    end

    def terminal value
      raise ArgumentError, "Trailing arguments after terminal value!" unless @predicates.empty?
      value
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
