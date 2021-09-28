require_relative "subquery_base"

class Magma
  class SubqueryFilter < Magma::SubqueryPredicateBase
    def create_subqueries(query_args)
      @subqueries << create_nested_subquery(query_args, predicate.model, predicate.alias_name)
    end

    private

    def create_nested_subquery(args, main_model, join_table_alias)
      verb, subquery_model_name_args, subquery_args = predicate.class.match_verbs(args, predicate, true)

      raise Magma::QuestionError, "This does not appear to be a valid subquery filter, #{args}." if subquery_model_name_args.first.is_a?(Array)

      subquery_model_name = subquery_model_name_args.first
      validate_attribute(main_model, subquery_model_name)

      subquery_model = model(subquery_model_name)

      is_one_to_many = one_to_many_relationship?(main_model, subquery_model)
      verb_applies = verb_applies_to_model?(subquery_args)

      original_subquery_args = subquery_args.dup

      internal_table_alias = random_alias_name
      derived_table_alias = random_alias_name

      nested_subqueries = []
      has_nested_subquery = has_nested_subquery?(original_subquery_args, subquery_model_name)
      begin
        nested_args = original_subquery_args.first.is_a?(Array) ? original_subquery_args.first : original_subquery_args
        nested_subqueries << create_nested_subquery(nested_args, subquery_model, internal_table_alias)
      end if has_nested_subquery

      # Always use SubqueryInner if it is a nested subquery...
      clazz = is_nested_subquery?(main_model) ? subquery_class : Magma::SubqueryInner
      clazz.new(
        subquery_model: subquery_model,
        derived_table_alias: derived_table_alias,
        main_table_alias: join_table_alias,
        main_table_join_column_name: main_table_join_column_name(main_model, subquery_model),
        internal_table_alias: internal_table_alias,
        subquery_pivot_column_name: subquery_pivot_column_name(main_model, subquery_model),
        filters: subquery_filters(subquery_args, internal_table_alias, subquery_model),
        subqueries: nested_subqueries,
        condition: verb_applies ? verb.do(:subquery_config).condition : nil,
      )
    end

    def main_table_join_column_name(main_model, subquery_model)
      if subquery_model.attributes[main_model.model_name].is_a?(Magma::ParentAttribute)
        "id"
      elsif subquery_model.attributes[main_model.model_name].is_a?(Magma::LinkAttribute)
        "id"
      else
        parent_column_name(main_model)
      end
    end

    def subquery_pivot_column_name(main_model, subquery_model)
      if subquery_model.attributes[main_model.model_name].is_a?(Magma::ParentAttribute)
        parent_column_name(subquery_model)
      elsif subquery_model.attributes[main_model.model_name].is_a?(Magma::LinkAttribute)
        subquery_model.attributes[main_model.model_name].column_name
      else
        "id"
      end
    end

    def is_nested_subquery?(model)
      model.model_name == predicate.model.model_name
    end

    def one_to_many_relationship?(start_model, end_model)
      # Returns boolean if start_model -> end_model is a collection,
      #   so one to many, which will require setting the
      #   subquery column to the right name.
      start_model.attributes[end_model.model_name].is_a?(Magma::CollectionAttribute)
    end

    def verb_applies_to_model?(subquery_args)
      # If subquery_args.first is not an array, and it
      #   is an actual model name, then the verb
      #   actually does not apply to the current subquery_model_name.
      # It most likely applies further down the model predicate chain.
      return true if subquery_args.first.is_a?(Array)

      begin
        next_model = model(subquery_args.first)
        return false
      rescue NameError
        return true # Not a real model, probably another predicate
      end
    end

    def validate_attribute(model, attribute_name)
      attribute = model.attributes[attribute_name.to_sym]

      raise Magma::QuestionError, "Invalid attribute, #{attribute_name}" if attribute.nil?
    end

    def has_nested_subquery?(args, model_name)
      # Should catch situations where a filter has a deep path
      #   to a model + filter subquery, like:
      #
      #   ["labors", "monster", "prize", ["worth", "::>", 4], "::every"]
      #
      # as elements get shifted from the Array.
      Magma::SubqueryUtils.is_subquery?(predicate, args) &&
        (!args.first.is_a?(Array) ?
          args.first != model_name :
          Magma::SubqueryUtils.is_subquery?(predicate, args.first))
    end

    def model(name)
      Magma.instance.get_model(predicate.model.project_name, name)
    end
  end
end
