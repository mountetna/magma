require_relative "subquery_base"

class Magma
  class SubqueryInner < Magma::SubqueryBase
    def apply(query, parent_query = nil)
      if parent_query
        binding.pry
        # There is a subquery that we have a constraint on,
        #   so we'll do a full_outer_join and then
        #   group by / sum to enforce the constraint.
        query.full_outer_join(
          subquery.as(derived_table_alias),
          Sequel.&(id_mapping)
        ).group_by(
          parent_query.subquery_column_alias.to_sym
        ).having(
          Sequel.lit(
            "SUM(CASE WHEN #{subquery_column_alias} IS NOT NULL THEN 1 ELSE 0 END) #{parent_query.condition}"
          )
        )
      else
        # Subquery with no ::every or ::any constraint,
        #   so we just implement the filter constraint
        #   and enforce it via an inner_join.
        # Create a derived table
        #   as the right-table
        #   filtered with GROUP BY and HAVING,
        #   COUNT(*) and SUM(), to ensure that
        #   the conditions are met.
        query.inner_join(
          subquery.as(derived_table_alias),
          Sequel.&(id_mapping)
        )
      end
    end

    def constraint
      # The inner join accomplishes what we need,
      #   but we'll inject a superfluous constraint
      #   to satisfy any wrapping ::and filters.
      Magma::Constraint.new(derived_table_alias,
                            {
        1 => 1,
      })
    end
  end
end
