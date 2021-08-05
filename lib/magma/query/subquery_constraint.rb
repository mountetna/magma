class Magma
  class SubqueryConstraint
    attr_reader :constraints, :subquery_pivot_column_name, :pivot_column_alias, :condition

    def initialize(constraints, subquery_pivot_column_name, pivot_column_alias, condition)
      @constraints = constraints
      @subquery_pivot_column_name = subquery_pivot_column_name
      @pivot_column_alias = pivot_column_alias
      @condition = condition
    end

    def apply(query)
      query = query.select(
        Sequel.as(
          subquery_pivot_column_name,
          pivot_column_alias
        )
      ).group_by(
        subquery_pivot_column_name
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
