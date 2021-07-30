require_relative "subquery_base"

class Magma
  class SubqueryOperator < Magma::SubqueryPredicateBase
    def create_boolean_subquery(subquery_args, condition)
      # These are always inner join subqueries on a single model.
      # Since just one table, join is on the parent_column_name.
      internal_table_alias = random_alias_name

      subquery_class.new(
        subquery_model: predicate.model,
        derived_table_alias: random_alias_name,
        main_table_alias: predicate.alias_name,
        main_table_join_column_name: parent_column_name(predicate.model),
        internal_table_alias: internal_table_alias,
        subquery_pivot_column_name: parent_column_name(predicate.model),
        filters: subquery_filters(subquery_args, internal_table_alias, predicate.model),
        condition: condition,
      )
    end

    def create_subqueries(args)
      verb, subquery_model_name_args, subquery_args = predicate.class.match_verbs(args, predicate, true)

      raise Magma::QuestionError, "This does not appear to be a valid subquery operator, #{args}." unless subquery_model_name_args.first.is_a?(Array)

      # This is a boolean subquery. Returns directly true / false.
      # Will never have a child / nested subquery.
      @subqueries << create_boolean_subquery(args, verb.do(:subquery_config).condition)
    end
  end
end
