class Magma
  class Subquery
    attr_reader :main_model, :subquery_model, :derived_table_alias, :main_table_alias, :fk_column_name

    def initialize(main_model, subquery_model, derived_table_alias, main_table_alias, fk_column_name, filters, condition)
      @main_model = main_model
      @subquery_model = subquery_model

      @derived_table_alias = derived_table_alias
      @main_table_alias = main_table_alias.to_sym
      @fk_column_name = fk_column_name.to_sym

      @filters = filters

      @constraints = @filters.map do |filter|
        Magma::SubqueryConstraint.new(
          subquery_model,
          filter,
          @fk_column_name,
          condition
        )
      end
    end

    def apply(query)
      # Create a derived table
      #   as the right-table
      #   filtered with GROUP BY and HAVING,
      #   COUNT(*) and SUM(), to ensure that
      #   the conditions are met.
      query.right_join(
        subquery.as(derived_table_alias),
        Sequel.&(id_mapping)
      )
    end

    def id_mapping
      {
        main_table_column => subquery_table_column,
      }
    end

    def main_table_column
      Sequel.qualify(main_table_alias, "id")
    end

    def subquery_table_column
      Sequel.qualify(derived_table_alias, fk_column_name)
    end

    def subquery
      new_query = subquery_model.from(
        subquery_model.table_name
      )

      @constraints.each { |c| new_query = c.apply(new_query) }

      new_query
    end
  end
end
