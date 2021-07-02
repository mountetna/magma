require_relative "subquery"

class Magma
  class SubqueryOuter < Magma::Subquery
    def apply(query)
      # Create a derived table
      #   as the right-table
      #   filtered with GROUP BY and HAVING,
      #   COUNT(*) and SUM(), to ensure that
      #   the conditions are met.

      # Full Outer join requires an additional
      #   clause to correctly mimic "OR"
      #   behavior at the top level.
      query.full_outer_join(
        subquery.as(derived_table_alias),
        Sequel.&(id_mapping)
      ).or(Sequel.|({
        subquery_table_column => subquery_table_column,
      }))
    end
  end
end
