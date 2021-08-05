class Magma
  class SubqueryBase
    attr_reader :subquery_model, :derived_table_alias, :main_table_alias, :main_table_join_column_name, :internal_table_alias, :subquery_pivot_column_name, :condition, :subqueries

    def initialize(subquery_model:, derived_table_alias:, main_table_alias:, main_table_join_column_name:, internal_table_alias:, subquery_pivot_column_name:, filters:, condition:, subqueries:)
      @subquery_model = subquery_model

      @derived_table_alias = derived_table_alias.to_sym
      @main_table_alias = main_table_alias.to_sym
      @internal_table_alias = internal_table_alias.to_sym
      @main_table_join_column_name = main_table_join_column_name.to_sym
      @subquery_pivot_column_name = subquery_pivot_column_name.to_sym

      @filters = filters
      @subqueries = subqueries
      @condition = condition

      @constraints = filter_constraints
    end

    def filter_constraints
      @filters.map do |filter|
        Magma::SubqueryConstraint.new(
          filter.flatten.map(&:constraint).inject(&:+),
          subquery_pivot_column_name,
          subquery_column_alias,
          condition
        )
      end
    end

    def apply(query)
      raise Exception, "Subclasses should implement this method"
    end

    def subquery_column_alias
      "#{derived_table_alias}_#{subquery_pivot_column_name}"
    end

    def subquery
      new_query = subquery_model.select(
        Sequel.as(
          Sequel.qualify(internal_table_alias, subquery_pivot_column_name),
          subquery_column_alias
        )
      ).from(
        Sequel.as(subquery_model.table_name, internal_table_alias)
      )

      @constraints.each { |c| new_query = c.apply(new_query) }
      @subqueries.each { |s| new_query = s.apply(new_query, condition ? self : nil) }

      new_query
    end

    def id_mapping
      {
        main_table_column => subquery_table_column,
      }
    end

    def main_table_column
      Sequel.qualify(main_table_alias, main_table_join_column_name)
    end

    def subquery_table_column
      subquery_column_alias.to_sym
    end

    def constraint
      raise Exception, "Subclasses should implement this method"
    end
  end
end
