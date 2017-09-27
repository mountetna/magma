# This is the base class for parsing a query (Question). Each argument in the
# question is a series of arguments which yield Predicates, starting with a
# ModelPredicate and ending with a TerminalPredicate. Each predicate determines
# what are the correct following arguments and validates accordingly.
#
# There are four basic types of predicates:
#
# ModelPredicate   - represents a list of records, its arguments are a series
# of filters on that list and various options to reduce that list.
# RecordPredicate  - represents a single record, its arguments are mostly a
# list of attribute names ColumnPredicate  - represents a value from a database
# table, its arguments are boolean tests on that value VectorPredicate  -
# represents an array of mapped values
# 
# From these predicates we wish to produce a SQL query. The basic form of such
# a query is defined by SELECT, FROM+JOIN, WHERE. Each predicate must therefore
# respond to #select, #join, #constraint. The Question will collect these and
# use them to make the SQL query.
#
# Each predicate consumes arguments from the argument chain until it is
# satisfied, and then returns a valid child predicate which is responsible for
# the rest. If a predicate does not know how to consume its arguments, it
# raises an error.
#
# Finally, each predicate will be handed the table of results from the SQL
# query. The columns in this table will be aliased so each predicate can
# recognize its relevant targets. Each predicate recursively hands down the
# table (or subsets of it) to its children through the #extract method, the
# final result of which will be a mapped value of some sort.

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
      if @verb.gives?(:join)
        [ @verb.do(:join) ]
      else
        []
      end
    end

    def constraint
      if @verb.gives?(:constraint)
        [ @verb.do(:constraint) ]
      else
        []
      end
    end

    def select
      []
    end

    def extract table, identity
      if @verb.gives?(:extract)
        @verb.do(:extract, table, identity)
      else
        child_extract(table,identity)
      end
    end

    def child_extract table, identity
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

    # This function takes the argument list and matches it to one of the
    # defined verbs for this predicate. If none exist, it raises an
    # error. If one exists, it sets @arguments, @query_args and @child_predicate
    def process_args(query_args)
      @verb, @arguments, @query_args = self.class.match_verbs(query_args, self)

      @child_predicate = @verb.do(:child)
    end

    def self.verb *args, &block
      @verbs ||= {}
      @verbs[args] = block
    end

    def self.match_verbs(query_args, predicate)
      @verbs ||= {}
      matching_args, matching_block = @verbs.find do |verb_args, block|
        verb_args.each.with_index.all? do |verb_arg, i|
          query_arg = query_args[i]
          case verb_arg
          when nil
            query_arg.nil?
          when Class
            query_arg.is_a?(verb_arg)
          when Array
            verb_arg.include?(query_arg)
          when Symbol
            predicate.send(verb_arg, query_arg)
          when String
            verb_arg == query_arg
          end
        end
      end
      return [
        Magma::Verb.new(predicate,matching_block),
        query_args[0...matching_args.size],
        query_args[matching_args.size..-1]
      ]
    end

    # Some constraint helpers
    def comparison_constraint column_name, operator, value
      new(
        Sequel.lit(
          "? #{operator.sub(/::/,'')} ?",
          Sequel.qualify(alias_name, column_name),
          value
        )
      )
    end

    def not_null_constraint(column_name)
      new(
        Sequel.lit(
          "? IS NOT NULL",
          Sequel.qualify(alias_name, column_name)
        )
      )
    end

    def basic_constraint column_name, value
      new(
        Sequel.lit(
          Sequel.qualify(alias_name, column_name) => value
        )
      )
    end

    def invalid_argument! argument
      raise ArgumentError, "Expected an argument to #{self.class.name}" if argument.nil?
      raise ArgumentError, "#{argument} is not a valid argument to #{self.class.name}"
    end

    def terminal value
      raise ArgumentError, "Trailing arguments after terminal value!" unless @query_args.empty?
      Magma::TerminalPredicate.new(value)
    end
  end
end

require_relative 'verb'
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
