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
          filter,
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

    def constraint_subselects
      # If this subquery contains a filter with yet another subquery at this point,
      #   i.e.
      #     ::any (self)
      #         ::and (@filters)
      #             constraint 1
      #             ::any (constraint 2 --> filter_constraints)
      #
      # We need to return a subselect for each new sub-constraint.
      filter_constraints.map do |filter_constraint|
        subselect = subquery_model.from(Sequel.as(subquery_model.table_name, internal_table_alias))
        subselect = filter_constraints.first.apply(subselect)

        # This subselect returns the list of IDs that are valid,
        #    according to the constraints.
        # We then need to return an ":id in <list>" constraint
        #    to satisfy the overall subquery.
        Magma::Constraint.new(
          derived_table_alias,
          Sequel.qualify(main_table_alias, main_table_join_column_name) => subselect,
        )
      end
    end
  end
end
