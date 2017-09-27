# This is the base class for parsing a query (Question). Each argument in the
# question is a series of arguments which yield Predicates, starting with a
# ModelPredicate and ending with a TerminalPredicate. Each predicate
# determines what are the correct following arguments and validates
# accordingly.
#
# There are four basic types of predicates:
#
# ModelPredicate   - represents a list of records, its arguments are a series
#                    of filters on that list and various options to reduce
#                    that list.
# RecordPredicate  - represents a single record, its arguments are mostly a
#                    list of attribute names
# ColumnPredicate  - represents a value from a database table, its
#                    arguments are boolean tests on that value
# VectorPredicate  - represents an array of mapped values
# 
# From these predicates we wish to produce a SQL query. The basic form of
# such a query is defined by SELECT, FROM+JOIN, WHERE. Each predicate must
# therefore respond to #select, #join, #constraint. The Question will
# collect these and use them to make the SQL query.
#
# Each predicate consumes arguments from the argument chain until it is
# satisfied, and then returns a valid child predicate which is responsible
# for the rest. If a predicate does not know how to consume its arguments,
# it raises an error.

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
      @child_predicate.is_a?(Predicate) ? @child_predicate.extract(table, identity) : table
    end

    def to_hash
      {
        type: self.class.name,
        argument: argument,
        join: join,
        constraint: constraint,
        select: select
      }
    end

    def flatten
      predicates = []
      predicate = self
      while predicate
        predicates << predicate
        predicate = predicate.respond_to?(:child_predicate) ? predicate.child_predicate : nil
      end
      predicates
    end

    def table_name
      @model.table_name if @model
    end

    def alias_name
      @alias_name ||= 10.times.map{ (97+rand(26)).chr }.join.to_sym
    end

    private

    def invalid_argument! argument
      raise ArgumentError, "Expected an argument to #{self.class.name}" if argument.nil?
      raise ArgumentError, "#{argument} is not a valid argument to #{self.class.name}"
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
require_relative 'predicate/metrics'
require_relative 'predicate/vector'
