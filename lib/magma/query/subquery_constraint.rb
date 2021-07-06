class Magma
  class SubqueryConstraint
    attr_reader :filter, :subquery_fk_column_name, :verb_name

    def initialize(filter, subquery_fk_column_name, verb_name)
      @filter = filter
      @subquery_fk_column_name = subquery_fk_column_name
      @verb_name = verb_name
    end

    def apply(query)
      query = query.select(
        subquery_fk_column_name
      ).group_by(
        subquery_fk_column_name
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
      @verb_name.to_s
    end

    def hash
      @verb_name.hash
    end

    def eql?(other)
      @verb_name == other.verb_name
    end

    private

    def literal(constraint)
      Magma.instance.db.literal(constraint.conditions.first)
    end

    def operator
      case verb_name
      when "::every"
        "="
      when "::any"
        ">"
      else
        raise ArgumentError, "Unrecognized verb_name, #{verb_name}"
      end
    end

    def value
      case verb_name
      when "::every"
        "count(*)"
      when "::any"
        "0"
      else
        raise ArgumentError, "Unrecognized verb_name, #{verb_name}"
      end
    end

    def constraints
      @constraints ||= @filter.flatten.map(&:constraint).inject(&:+)
    end
  end
end
