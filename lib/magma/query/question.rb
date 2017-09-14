require_relative 'predicate'

# A query for a piece of data. Each question is a path through the data
# hierarchy/schema/graph or whatever you want to call it. The basic idea is
# that a query begins at some model and ends at a data column (string, number,
# etc.). Along the way it transits through a list of relationships between
# models, e.g.:
#
# "sample" -> "patient" -> "experiment" -> "name"
#
# Links in this chain are attribute names - for example, the "sample" model has
# an attribute "patient" which links it to the "patient" model. If we traverse
# through another model, we must continue traversing through the graph until we
# arrive at a data column ("name"), at which point our query ends. Then we have
# connected a model ("sample") to a piece of associated data ("name" from a
# corresponding "experiment")
#
# This would suffice to detail a query, except that some links between models
# are one-to-many relationships. Also, the first item in our query will always
# be a model - a collection of records. In these cases we have two options:
# 1) Collect all or some of these relationships and return a list.
# 2) Return a single item from the list
#
# In both of these cases, we will want to filter the list down.
# A filter is another path through the graph, starting from the model we want
# to filter and ending in a boolean value. E.g.:
#
# "sample" -> "patient" -> "experiment" -> "name"
#
# Here "sample" is a list, so we can filter it on another criterion. A simple
# filter might be on one of "sample"'s own attributes, let's say "sample_name"
#
# "sample" -> "sample_name" -> "::matches" -> "Sample[4-5]"
#
# Data columns allow various boolean tests; in this case, we are using a 'match'
# criterion and a regular expression on the 'sample_name' string column.
#
# Putting these together gives us a full query:
#
# [ "sample", [ "sample_name", "::matches", "Sample[4-5]" ], "::all", "patient", "experiment", "name" ]

class Magma
  class Question
    class Join
      def initialize(t1, t1_alias, t1_id, t2, t2_alias, t2_id)
        @table1 = t1
        @table1_alias = t1_alias.to_sym
        @table1_id = t1_id.to_sym
        @table2_alias = t2_alias.to_sym
        @table2_id = t2_id.to_sym
      end

      def apply query
        query.left_outer_join(
          Sequel.as(@table1,@table1_alias),
          table1_column => table2_column
        )
      end

      def to_s
        {table1_column=> table2_column}.to_s
      end

      def table1_column
        Sequel.qualify(@table1_alias, @table1_id)
      end

      def table2_column
        Sequel.qualify(@table2_alias, @table2_id)
      end

      def hash
        table1_column.hash + table2_column.hash
      end

      def eql?(other)
        table1_column == other.table1_column && table2_column == other.table2_column
      end
    end

    class Constraint
      attr_reader :conditions

      def initialize(*args)
        @conditions = args
      end

      def apply(query)
        query.where(*@conditions)
      end

      def to_s
        @conditions.to_s
      end

      def hash
        @conditions.hash
      end

      def eql?(other)
        @conditions == other.conditions
      end
    end

    def initialize(project_name, predicates, options = {})
      @model = Magma.instance.get_model(project_name, predicates.shift)
      @start_predicate = ModelPredicate.new(@model, *predicates)
      @options = options
    end

    # allow us to re-use the same question for a different page
    def set_page page
      @options[:page] = page
    end

    def answer
      table = to_table

      @start_predicate.extract(table, identity)
    end

    def predicates
      @predicates ||= @start_predicate.flatten
    end

    def identity
      Sequel.qualify(@start_predicate.alias_name, @model.identity)
    end

    def type
      @start_predicate.reduced_type
    end

    def to_predicates
      predicates.map do |pred|
        pred.to_hash
      end
    end

    def count
      count_query.count
    end

    private

    def to_table
      Magma.instance.db[
        to_sql
      ].all
    end

    def to_sql
      query = base_query

      # do you have page bounds? if so, compute them here.
      if @options[:page] && @options[:page_size]
        query = paged_query( query )
      end

      query = query.select(
        *(predicate_collect(:select)).uniq
      )

      query.sql
    end

    # The base query joins all of the tables and applies constraints for this
    # question, but does not select any columns
    def base_query
      query = @model.from(
        Sequel.as(@model.table_name, @start_predicate.alias_name)
      ).order(@start_predicate.identity)

      predicate_collect(:join).uniq.each do |join|
        query = join.apply(query)
      end

      predicate_collect(:constraint).uniq.each do |constraint|
        query = constraint.apply(query)
      end

      query
    end

    # return distinct identifiers, useful for counting results and row-numbering
    def count_query
      base_query.select(
        *@start_predicate.select
      ).distinct(
        @start_predicate.column_name
      )
    end

    # get page bounds for this question using @options[:page] and @options[:page_size]
    def bounds_query
      count_query.from_self.select(
        # add row_numbers to the count query
        @start_predicate.identity,
        Sequel.function(:row_number)
          .over(order: @start_predicate.identity)
          .as(:row)
      ).from_self(alias: :main_query).select(
        # only the first row from each page
        @start_predicate.identity).where(
          Sequel.lit(
            '? % ? = 1',
            Sequel[:main_query][:row],
            @options[:page_size]
          )
        )
        .limit(2)
        .offset(@options[:page]-1)
        # return only the 2 identifiers for this page
    end

    def paged_query(query)
      raise ArgumentError, "Page must start at 1" unless @options[:page] > 0
      bounds = Magma.instance.db[bounds_query.sql].all.map do |row|
        row[@start_predicate.identity]
      end
      raise ArgumentError, "Page #{@options[:page]} not found" if bounds.empty?

      # apply bounds to the query
      query = query.where(
        Sequel.lit(
          '? >= ?',
          @start_predicate.column_name,
          bounds.first
        )
      )
      if bounds.length > 1
        query = query.where(
          Sequel.lit(
            '? < ?',
            @start_predicate.column_name,
            bounds.last
          )
        )
      end
      query
    end

    def predicate_collect type
      predicates.map(&type).inject(&:+) || []
    end
  end
end
