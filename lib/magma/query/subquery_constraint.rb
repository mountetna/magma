class Magma
  class SubqueryConstraint
    attr_reader :constraints, :subquery_pivot_column_name, :pivot_column_alias, :condition

    def initialize(filter, subquery_pivot_column_name, pivot_column_alias, condition)
      @constraints = filter.flatten.map(&:constraint).inject(&:+)
      @subqueries = filter.subquery
      @subquery_pivot_column_name = subquery_pivot_column_name
      @pivot_column_alias = pivot_column_alias
      @condition = condition
    end

    def select_columns
      columns = [
        Sequel.as(
          subquery_pivot_column_name,
          pivot_column_alias
        ),
      ]

      # If there are subqueries that are part of the filter, we'll
      #   need to add the ID column of this subquery so our
      #   sub-select join will work. Will also have to group_by
      #   the id.
      # columns << :id if requires_join_with_subquery?

      columns
    end

    def requires_join_with_subquery?
      !@subqueries.empty?
    end

    def group_by_columns
      columns = [
        subquery_pivot_column_name,
      ]

      # columns << :id if requires_join_with_subquery?

      columns
    end

    def apply(query)
      query = query.select(
        *select_columns
      ).group_by(
        *group_by_columns
      )

      constraints.each do |constraint|
        # The CASE WHEN clause is a bit too complicated for
        #   Sequel built-in methods, so we'll construct
        #   it manually.
        query = query.having(
          Sequel.lit(
            "SUM(CASE WHEN #{literal(constraint)} THEN 1 ELSE 0 END) #{condition}"
          )
        )
      end

      # Don't directly apply the subqueries to the query here.
      # require "pry"
      # binding.pry
      # @subqueries.each do |subquery|
      #   query = subquery.apply(query)
      # end

      query
    end

    def to_s
      @condition.to_s
    end

    def hash
      @condition.hash
    end

    def eql?(other)
      @condition == other.condition
    end

    private

    def literal(constraint)
      Magma.instance.db.literal(constraint.conditions.first)
    end
  end
end
