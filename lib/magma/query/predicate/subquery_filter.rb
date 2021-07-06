require_relative "subquery_base"

class Magma
  class SubqueryFilter < Magma::SubqueryPredicateBase
    def create_subquery(join_type, args, parent_model = predicate.model, join_table_alias = nil)
      verb, subquery_model_name_array, subquery_args = predicate.class.match_verbs(args, predicate, true)

      raise Exception, "This does not appear to be a valid subquery filter, #{args}." if subquery_model_name_array.first.is_a?(Array)

      subquery_model_name = subquery_model_name_array.first
      validate_attribute(parent_model, subquery_model_name)

      subquery_model = model(parent_model.project_name, subquery_model_name)

      original_subquery_args = subquery_args.dup

      internal_table_alias = subquery_internal_alias_name

      subquery_class = join_type == "inner" ?
        Magma::SubqueryInner :
        Magma::SubqueryOuter

      @subqueries << subquery_class.new(
        subquery_model: subquery_model,
        derived_table_alias: derived_table_alias_name(args),
        main_table_alias: join_table_alias || predicate.alias_name,
        main_table_join_column_name: "id",
        internal_table_alias: internal_table_alias,
        fk_column_name: parent_column_name(subquery_model),
        filters: subquery_filters(subquery_args, internal_table_alias, subquery_model),
        verb_name: subquery_args.last,
        include_constraint: !has_nested_subquery?(predicate, original_subquery_args, subquery_model_name),
      )

      if has_nested_subquery?(predicate, original_subquery_args, subquery_model_name)
        # This must be another model subquery that we have to join in
        # Do this after adding the parent subquery so that
        #   the parent model's derived table is already declared.
        create_subquery(
          join_type,
          original_subquery_args,
          subquery_model,
          derived_table_alias_name(args)
        )
      end
    end

    private

    def validate_attribute(model, attribute_name)
      attribute = model.attributes[attribute_name.to_sym]

      raise ArgumentError, "Invalid attribute, #{attribute_name}" if attribute.nil?
    end

    def has_nested_subquery?(predicate, args, model_name)
      Magma::SubqueryUtils.is_subquery_query?(predicate, args) &&
        !args.first.is_a?(Array) &&
        args.first != model_name
    end

    def model(project_name, name)
      Magma.instance.get_model(project_name, name)
    end
  end
end
