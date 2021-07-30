class Magma
  class SubqueryConstraint
    attr_reader :filter, :subquery_pivot_column_name, :condition

    def initialize(filter, subquery_pivot_column_name, condition)
      @filter = filter
      @subquery_pivot_column_name = subquery_pivot_column_name
      @condition = condition
    end

    def apply(query)
      query = query.select(
        subquery_pivot_column_name
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

    def constraints
      @constraints ||= @filter.flatten.map(&:constraint).inject(&:+)
    end
  end
end
