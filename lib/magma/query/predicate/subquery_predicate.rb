require_relative "subquery_base"

class Magma
  class SubqueryPredicate < Magma::SubqueryPredicateBase
    def create_boolean_subquery(subquery_model_name, subquery_args, subquery_model)
      # These are always inner join subqueries since on a single model.
      # Same table, join is on the parent_column_name.
      internal_table_alias = subquery_internal_alias_name

      Magma::SubqueryInner.new(
        subquery_model: subquery_model,
        derived_table_alias: derived_table_alias_name(subquery_args),
        main_table_alias: predicate.alias_name,
        main_table_join_column_name: parent_column_name(subquery_model),
        internal_table_alias: internal_table_alias,
        fk_column_name: parent_column_name(subquery_model),
        filters: subquery_filters(subquery_args, internal_table_alias, subquery_model),
        verb_name: subquery_args.last,  # the verb_name, i.e. ::every or ::any
      )
    end

    def create_subquery(join_type, args, parent_model = predicate.model, join_table_alias = nil)
      verb, subquery_model_name_array, subquery_args = predicate.class.match_verbs(args, predicate, true)

      raise Exception, "This does not appear to be a valid subquery predicate, #{args}." unless subquery_model_name_array.first.is_a?(Array)

      # This is a boolean subquery. Returns directly true / false.
      # Will never have a child / nested subquery.
      @subqueries << create_boolean_subquery(parent_model.model_name.to_s, args, parent_model)
    end
  end
end
