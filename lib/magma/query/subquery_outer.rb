require_relative "subquery"

class Magma
  class SubqueryOuter < Magma::Subquery
    def apply(query)
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
      # Full Outer join requires an additional
      #   clause to correctly mimic "OR"
      #   behavior at the top level.
      Magma::Constraint.new(derived_table_alias,
                            {
        subquery_table_column => subquery_table_column,
      }) if add_constraint
    end
  end
end
