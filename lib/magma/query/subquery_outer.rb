require_relative "subquery_base"

class Magma
  class SubqueryOuter < Magma::SubqueryBase
    def apply(query, parent_query = nil)
      # Create a derived table
      #   as the right-table
      #   filtered with GROUP BY and HAVING,
      #   COUNT(*) and SUM(), to ensure that
      #   the conditions are met.
      query.full_outer_join(
        subquery.as(derived_table_alias),
        Sequel.&(id_mapping)
      )
    end

    def constraint
      return constraint_subselects unless filter_constraints.empty?

      # Full Outer join requires an additional
      #   clause to correctly mimic "OR"
      #   behavior at the top level.
      Magma::Constraint.new(derived_table_alias,
                            {
        subquery_table_column => subquery_table_column,
      })
    end
  end
end
