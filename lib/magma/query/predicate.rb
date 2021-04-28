# This is the base class for parsing a query (Question). Each argument in the
# question is a series of arguments which yield Predicates, starting with a
# ModelPredicate and ending with a TerminalPredicate. Each predicate determines
# what are the correct following arguments and validates accordingly.
#
# There are four basic types of predicates:
#
# ModelPredicate   - represents a list of records, its arguments are a series
#                    of filters on that list and various options to reduce that
#                    list.
# RecordPredicate  - represents a single record, its arguments are mostly a
#                    list of attribute names
# ColumnPredicate  - represents a value from a database table, its arguments
#                    are boolean tests on that value
# TablePredicate   - represents an array of mapped values
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

    def initialize(question)
      @question = question
    end

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

    def inspect
      <<EOT
#<#{self.class.name}:#{object_id}
    @alias_name=#{@alias_name}
    @arguments=#{@arguments}
    @child_predicate=#<#{@child_predicate.class.name}:#{@child_predicate.object_id}
  >
EOT
    end

    def join
      if @verb && @verb.gives?(:join)
        [ @verb.do(:join) ].flatten.compact
      else
        []
      end
    end

    def constraint
      if @verb && @verb.gives?(:constraint)
        [ @verb.do(:constraint) ].compact
      else
        []
      end
    end

    def select
      []
    end

    def extract table, identity
      if @verb && @verb.gives?(:extract)
        @verb.do(:extract, table, identity)
      else
        child_extract(table,identity)
      end
    end

    def child_extract table, identity
      @child_predicate.is_a?(Predicate) ? @child_predicate.extract(table, identity) : table
    end

    def format
      if @verb && @verb.gives?(:format)
        @verb.do(:format)
      else
        child_format
      end
    end

    def child_format
      @child_predicate.is_a?(Predicate) ? @child_predicate.format : nil
    end

    def default_format
      "#{@model.project_name}::#{@model.model_name}##{@attribute_name || @model.identity.attribute_name}" if @model
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

      @verb.do(:validate,@arguments)

      @child_predicate = @verb.do(:child)
    end

    def join_filters
      @filters.map do |filter|
        filter.flatten.map(&:join).inject(&:+) || []
      end.inject(&:+) || []
    end

    # Code relating to defining and looking up predicate verbs
    class << self
      def verbs
        @verbs ||= {}
      end

      def verb *args, &block
        verbs[args] = block
      end

      def match_verbs(query_args, predicate)
        matching_args, matching_block = verbs.find do |verb_args, block|
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

        # this will raise a QuestionError
        predicate.send(:invalid_argument!,query_args.first) if matching_args.nil?

        return [
          Magma::Verb.new(predicate,matching_block),
          query_args[0...matching_args.size],
          query_args[matching_args.size..-1] || []
        ]
      end

      def inherited(subclass)
        @descendants ||= []
        @descendants << subclass unless subclass == Magma::ColumnPredicate
      end

      def to_json
        response = {
          predicates: Hash[
            @descendants.map do |pred_class|
              [
                pred_class.predicate_name,
                pred_class.verbs.map do |args, block|
                  {
                    args: args,
                    return_type: Magma::Verb.new(nil,block).return_type
                  }
                end
              ]
            end
          ]
        }

        response.to_json
      end

      def predicate_name
        name.snake_case.sub(/^magma::/,'').sub(/_predicate/,'')
      end
    end

    # Some constraint helpers
    def comparison_constraint column_name, operator, value
      Magma::Constraint.new(
        alias_name,
        Sequel.lit(
          "? #{operator.sub(/::/,'')} ?",
          Sequel.qualify(alias_name, column_name),
          value
        )
      )
    end

    def not_null_constraint(column_name)
      Magma::Constraint.new(
        alias_name,
        Sequel.negate(
          Sequel.qualify(alias_name, column_name) => nil
        )
      )
    end

    def null_constraint(column_name)
      Magma::Constraint.new(
        alias_name,
        Sequel.qualify(alias_name, column_name) => nil
      )
    end

    def not_constraint column_name, value
      Magma::Constraint.new(
        alias_name,
        Sequel.negate(
          Sequel.qualify(alias_name, column_name) => value
        )
      )
    end

    def or_constraint constraints
      Magma::Constraint.new(
        alias_name,
        Sequel.|(
          *constraints.map(&:conditions)
        )
      )
    end

    def and_constraint constraints
      Magma::Constraint.new(
        alias_name,
        Sequel.&(
          *constraints.map(&:conditions)
        )
      )
    end

    def basic_constraint column_name, value
      Magma::Constraint.new(
        alias_name,
        Sequel.qualify(alias_name, column_name) => value
      )
    end

    def double_cast_comparison_constraint column_name, operator, value
      Magma::Constraint.new(
        alias_name,
        Sequel.lit(
          "CAST(? as DOUBLE PRECISION) #{operator.sub(/::/,'')} ?",
          Sequel.qualify(alias_name, column_name),
          value
        )
      )
    end

    def is_numeric_constraint column_name      
      Magma::Constraint.new(
        alias_name,
        Sequel.qualify(alias_name, column_name) => Regexp.new(/\d+/)
      )
    end

    def json_constraint column_name, key, value
      Magma::Constraint.new(
        alias_name,
        Sequel.pg_json_op(
          Sequel.qualify(alias_name, column_name)
        ).get_text(key) => value
      )
    end

    def not_json_constraint column_name, key, value
      Magma::Constraint.new(
        alias_name,
        Sequel.negate(
          Sequel.pg_json_op(
            Sequel.qualify(alias_name, column_name)
          ).get_text(key) => value
        )
      )
    end

    def invalid_argument! argument
      raise QuestionError, "Expected an argument to #{self.class.name}" if argument.nil?
      raise QuestionError, "#{argument} is not a valid argument to #{self.class.name}"
    end

    def terminal value
      raise QuestionError, "Trailing arguments after terminal value! #{@query_args}" unless @query_args.empty?
      Magma::TerminalPredicate.new(@question, value)
    end
  end
end

require_relative 'verb'
require_relative 'predicate/column'
require_relative 'predicate/model'
require_relative 'predicate/start'
require_relative 'predicate/record'
require_relative 'predicate/filter'
require_relative 'predicate/boolean'
require_relative 'predicate/date_time'
require_relative 'predicate/file'
require_relative 'predicate/file_collection'
require_relative 'predicate/match'
require_relative 'predicate/number'
require_relative 'predicate/string'
require_relative 'predicate/terminal'
require_relative 'predicate/metrics'
require_relative 'predicate/table'
require_relative 'predicate/matrix'
