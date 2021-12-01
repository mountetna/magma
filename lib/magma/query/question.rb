require_relative 'predicate'
require_relative 'join'
require_relative 'constraint'
require_relative 'query_executor'

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
  class QuestionError < StandardError
  end

  class Question
    attr_reader :user, :model
    def initialize(project_name, query_args, options = {})
      @project_name = project_name
      @model = Magma.instance.get_model(project_name, query_args.shift)
      @options = options
      @user = options[:user]
      @start_predicate = StartPredicate.new(self, @model, *query_args)
    end

    # allow us to re-use the same question for a different page
    def set_page page
      @options[:page] = page
    end

    def restrict?
      @options[:restrict]
    end

    def show_disconnected?
      @options[:show_disconnected]
    end

    def answer
      table = to_table(query)

      @start_predicate.extract(table, identity)
    end

    def each_page_answer
      all_bounds.each do |bound|
        query = base_query.select(
            *(predicate_collect(:select)).uniq
        )
        query = apply_bounds(query, bound[:lower], bound[:upper])
        table = to_table(query)
        page_answer = @start_predicate.extract(table, identity)
        yield page_answer
      end
    end

    def predicates
      @predicates ||= @start_predicate.flatten
    end

    def identity
      Sequel.qualify(@start_predicate.alias_name, @model.identity.column_name)
    end

    def type
      @start_predicate.reduced_type
    end

    def format
      @start_predicate.format
    end

    def to_predicates
      predicates.map do |pred|
        pred.to_hash
      end
    end

    def count
      count_query.count
    end

    def columns
      format_helper = Magma::QuestionFormat.new(
        @project_name,
        format
      )

      format_helper.leaves
    end

    private

    def to_table(query)
      Magma::QueryExecutor.new(query, @options[:timeout], Magma.instance.db).execute
    end

    def query
      query = base_query

      # do you have page bounds? if so, compute them here.
      if @options[:page] && @options[:page_size]
        query = paged_query(query)
      end

      query = query.select(
          *(predicate_collect(:select)).uniq
      )

      query
    end

    def order_by_attributes
      @order_by_attributes ||= begin
        order_columns = []
        if @options[:order]
          order_columns << @options[:order]
        end
        order_columns << @start_predicate.identity
      end
    end

    def order_by_aliases
      @order_by_aliases ||= order_by_attributes.map { |attr| @start_predicate.alias_for_attribute(attr) }
    end

    def order_by_column_names
      @order_by_column_names ||= order_by_attributes.map { |attr| @start_predicate.column_name(attr) }
    end

    # The base query joins all of the tables and applies constraints for this
    # question, but does not select any columns
    def base_query
      query = @model.from(
          Sequel.as(@model.table_name, @start_predicate.alias_name)
      )

      query = query.order(*order_by_column_names)

      joins = predicate_collect(:join).uniq
      constraints = predicate_collect(:constraint).uniq
      subqueries = predicate_collect(:subquery).uniq

      joins.each do |join|
        query = join.apply(query)
      end

      constraints.each do |constraint|
        query = constraint.apply(query)
      end

      subqueries.each do |subquery|
        query = subquery.apply(query)
      end

      query
    end

    # return identifiers, useful for counting results and row-numbering
    def count_query
      # unlike the base query, we do not want to collect joins for mapped
      # values, only for filters on the start_predicate.

      query = @model.from(
          Sequel.as(@model.table_name, @start_predicate.alias_name)
      ).order(@start_predicate.identity)

      joins = @start_predicate.join.uniq
      constraints = @start_predicate.constraint.uniq
      subqueries = @start_predicate.subquery.uniq

      joins.each do |join|
        query = join.apply(query)
      end

      constraints.each do |constraint|
        query = constraint.apply(query)
      end

      subqueries.each do |subquery|
        query = subquery.apply(query)
      end

      query.distinct.select(
          *order_by_column_names.zip(order_by_aliases).map { |c, a| c.as(a) }
      )
    end

    # get page bounds for this question using @options[:page] and @options[:page_size]
    def bounds_query
      raise QuestionError, 'Page size must be greater than 1' unless @options[:page_size] > 1
      bounds_select_parts = order_by_aliases.dup
      bounds_select_parts << Sequel.function(:row_number)
                             .over(order: order_by_aliases)
                             .as(:row)

      count_query.from_self.select(
          *bounds_select_parts
      ).from_self(alias: :main_query).select(
          # only the first row from each page
          *order_by_aliases).where(
          Sequel.lit(
              '? % ? = 1',
              Sequel[:main_query][:row],
              @options[:page_size]
          )
      )
    end

    def page_bounds_query
      bounds_query.limit(2).offset(@options[:page] - 1)
    end

    # create an upper and lower limit for each page bound
    def all_bounds
      bounds = to_table(bounds_query)
      bounds.map.with_index do |row, index|
        bound = {:lower => order_by_aliases.map { |c| row[c] }, :upper => nil}


        if bounds[index + 1]
          bound[:upper] = order_by_aliases.map{ |c| bounds[index + 1][c] }
        end

        bound
      end
    end

    def apply_multi_stage_ordering_bounds(query, upper: nil, lower: nil)
      bounds = upper || lower
      prev = upper ? Sequel.lit('TRUE') : Sequel.lit('FALSE')
      start = lower ? Sequel.lit('TRUE') : Sequel.lit('FALSE')
      operator = upper ? '<' : '>='

      # upper (a < 1 & true) | (b < 2 & (a == 1 & true))
      # lower (a >= 1 | false) & (b >= 2 | (a != 1 | false)) & (c >= 5 | (b != 2 | (a != 1 | false)))
      query.where(order_by_column_names.zip(bounds).reduce(start) do |cond, n|
        column, value = n

        if value.nil? && upper
          step = Sequel.lit('FALSE')
        elsif value.nil? && lower
          step = Sequel.lit('TRUE')
        else
          step = Sequel.lit(
              "? #{operator} ?",
              column,
              value
          )
        end

        next_cond = nil
        if upper
          next_cond = Sequel.lit('(? AND ?)', step, prev)
        elsif lower
          next_cond = Sequel.lit('(? OR ?)', step, prev)
        end

        if upper
          if value.nil?
            prev = Sequel.lit("(? IS NULL AND ?)", column, prev)
          else
            prev = Sequel.lit("(? = ? AND ?)", column, value, prev)
          end

          Sequel.lit('(? OR ?)', cond, next_cond)
        elsif lower
          if value.nil?
            prev = Sequel.lit("(? IS NOT NULL OR ?)", column, prev)
          else
            prev = Sequel.lit("(? != ? OR ?)", column, value, prev)
          end

          Sequel.lit('(? AND ?)', cond, next_cond)
        end
      end)
    end

    def apply_bounds(query, lower, upper)
      query = apply_multi_stage_ordering_bounds(query, lower: lower)

      if upper
        query = apply_multi_stage_ordering_bounds(query, upper: upper)
      end

      query
    end

    def paged_query(query)
      raise QuestionError, 'Page must start at 1' unless @options[:page] > 0
      bounds = to_table(page_bounds_query).map do |row|
        order_by_aliases.map { |c| row[c] }
      end
      raise QuestionError, "Page #{@options[:page]} not found" if bounds.empty?

      apply_bounds(query, bounds[0], bounds[1])
    end

    def predicate_collect type
      predicates.map(&type).inject(&:+) || []
    end
  end
end
