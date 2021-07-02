require_relative "subquery"

class Magma
  class SubqueryInner < Magma::Subquery
    def apply(query)
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
end
