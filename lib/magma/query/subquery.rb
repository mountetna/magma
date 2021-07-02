class Magma
  class Subquery
    attr_reader :subquery_model, :derived_table_alias, :main_table_alias, :main_table_join_column_name, :internal_table_alias, :fk_column_name

    def initialize(subquery_model:, derived_table_alias:, main_table_alias:, main_table_join_column_name:, internal_table_alias:, fk_column_name:, filters:, condition:)
      @subquery_model = subquery_model

      @derived_table_alias = derived_table_alias.to_sym
      @main_table_alias = main_table_alias.to_sym
      @internal_table_alias = internal_table_alias.to_sym
      @main_table_join_column_name = main_table_join_column_name.to_sym
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
      # Override this in subclasses
      query
    end

    def subquery
      new_query = subquery_model.from(
        Sequel.as(subquery_model.table_name, internal_table_alias)
      )

      @constraints.each { |c| new_query = c.apply(new_query) }

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
      Sequel.qualify(derived_table_alias, fk_column_name)
    end
  end
end
