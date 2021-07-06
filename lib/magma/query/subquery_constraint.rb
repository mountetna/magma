class Magma
  class SubqueryConstraint
    attr_reader :subquery_model, :filter, :parent_attribute, :verb_name

    def initialize(subquery_model, filter, parent_attribute, verb_name)
      @subquery_model = subquery_model
      @filter = filter
      @parent_attribute = parent_attribute
      @verb_name = verb_name
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
