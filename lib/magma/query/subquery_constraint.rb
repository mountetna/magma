class Magma
  class SubqueryConstraint
    attr_reader :subquery_model, :filter, :parent_attribute, :condition

    def initialize(subquery_model, filter, parent_attribute, condition)
      @subquery_model = subquery_model
      @filter = filter
      @parent_attribute = parent_attribute
      @condition = condition
    end

    def apply(query)
      query = query.select(
        parent_attribute
      ).group_by(
        parent_attribute
      )

      constraints.each do |constraint|
        # The WHEN clause is a bit too complicated for
        #   Sequel built-in methods, so we'll construct
        #   it manually.
        query = query.having(
          Sequel.lit(
            "SUM(CASE WHEN #{literal(constraint)} THEN 1 ELSE 0 END) #{operator} #{value}"
          )
        )
      end

      query
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

    private

    def literal(constraint)
      Magma.instance.db.literal(constraint.conditions.first)
    end

    def operator
      case condition
      when "::every"
        "="
      when "::any"
        ">"
      else
        raise ArgumentError, "Unrecognized condition, #{condition}"
      end
    end

    def value
      case condition
      when "::every"
        "count(*)"
      when "::any"
        "0"
      else
        raise ArgumentError, "Unrecognized condition, #{condition}"
      end
    end

    def constraints
      @constraints ||= @filter.flatten.map(&:constraint).inject(&:+)
    end
  end
end
