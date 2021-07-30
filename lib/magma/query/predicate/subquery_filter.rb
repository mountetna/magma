require_relative "subquery_base"

class Magma
  class SubqueryFilter < Magma::SubqueryPredicateBase
    def create_subqueries(query_args)
      main_model = predicate.model
      join_table_alias = predicate.alias_name
      args = query_args

      loop do
        verb, subquery_model_name_args, subquery_args = predicate.class.match_verbs(args, predicate, true)

        raise Magma::QuestionError, "This does not appear to be a valid subquery filter, #{args}." if subquery_model_name_args.first.is_a?(Array)

        subquery_model_name = subquery_model_name_args.first
        validate_attribute(main_model, subquery_model_name)

        subquery_model = model(subquery_model_name)

        is_down_graph = going_down_graph?(main_model, subquery_model)

        original_subquery_args = subquery_args.dup

        internal_table_alias = random_alias_name
        derived_table_alias = random_alias_name

        has_nested_subquery = has_nested_subquery?(original_subquery_args, subquery_model_name)

        @subqueries << subquery_class.new(
          subquery_model: subquery_model,
          derived_table_alias: derived_table_alias,
          main_table_alias: join_table_alias,
          main_table_join_column_name: is_down_graph ? "id" : parent_column_name(main_model),
          internal_table_alias: internal_table_alias,
          subquery_pivot_column_name: is_down_graph ? parent_column_name(subquery_model) : "id",
          filters: subquery_filters(subquery_args, internal_table_alias, subquery_model),
          condition: verb.do(:subquery_config).condition,
          include_constraint: !has_nested_subquery,
        )

        break unless has_nested_subquery

        main_model = subquery_model
        join_table_alias = derived_table_alias.dup
        args = original_subquery_args
      end
    end

    private

    def going_down_graph?(start_model, end_model)
      # Returns boolean if start_model is parent of end_model, so
      #   the relationship is one-to-many.
      end_model.parent_model_name == start_model.model_name
    end

    def validate_attribute(model, attribute_name)
      attribute = model.attributes[attribute_name.to_sym]

      raise ArgumentError, "Invalid attribute, #{attribute_name}" if attribute.nil?
    end

    def has_nested_subquery?(args, model_name)
      # Should catch situations where a filter has a deep path
      #   to a model + filter subquery, like:
      #
      #   ["labors", "monster", "prize", ["worth", "::>", 4], "::every"]
      #
      # as elements get shifted from the Array.
      Magma::SubqueryUtils.is_subquery?(predicate, args) &&
        !args.first.is_a?(Array) &&
        args.first != model_name
    end

    def model(name)
      Magma.instance.get_model(predicate.model.project_name, name)
    end
  end
end
