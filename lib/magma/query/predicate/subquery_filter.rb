require_relative "subquery_base"

class Magma
  class SubqueryFilter < Magma::SubqueryPredicateBase
    def create_subqueries(query_args)
      parent_model = predicate.model
      join_table_alias = predicate.alias_name
      args = query_args

      loop do
        verb, subquery_model_name_args, subquery_args = predicate.class.match_verbs(args, predicate, true)

        raise Magma::QuestionError, "This does not appear to be a valid subquery filter, #{args}." if subquery_model_name_args.first.is_a?(Array)

        subquery_model_name = subquery_model_name_args.first
        validate_attribute(parent_model, subquery_model_name)

        subquery_model = model(subquery_model_name)

        original_subquery_args = subquery_args.dup

        internal_table_alias = random_alias_name
        derived_table_alias = random_alias_name

        has_nested_subquery = has_nested_subquery?(original_subquery_args, subquery_model_name)

        @subqueries << subquery_config.magma_class.new(
          subquery_model: subquery_model,
          derived_table_alias: derived_table_alias,
          main_table_alias: join_table_alias,
          main_table_join_column_name: "id",
          internal_table_alias: internal_table_alias,
          subquery_fk_column_name: parent_column_name(subquery_model),
          filters: subquery_filters(subquery_args, internal_table_alias, subquery_model),
          condition: verb.do(:subquery_config).condition,
          include_constraint: !has_nested_subquery,
        )

        break unless has_nested_subquery

        parent_model = subquery_model
        join_table_alias = derived_table_alias.dup
        args = original_subquery_args
      end
    end

    private

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
