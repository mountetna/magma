require "digest"
require "json"

class Magma
  class SubqueryPredicate < Magma::ModelPredicate
    # Subquery predicate utils - this helps manage the creation
    #     of subqueries for ModelPredicates, when
    #     any of the following list operators are used:
    #
    #      ::any - a Boolean that returns true if the list is non-zero
    #      ::every - a Boolean that returns true if every item in the list is non-zero

    attr_reader :model_predicate

    def self.verbs
      Magma::ModelPredicate.verbs
    end

    def initialize(model_predicate, question)
      @question = question
      @model_predicate = model_predicate
    end

    def partition_args(query_args, preceding_predicate = "::and")
      subquery_args = []
      filter_args = []

      if query_args.is_a?(Array) && is_subquery_query?(query_args)
        arry = []

        # BLAH, what is better than this?
        if preceding_predicate == "::or"
          arry << "full_outer"
        elsif preceding_predicate == "::and"
          # Inner join automatically applies an "AND"
          #   effect with subsequent filters.
          arry << "inner"
        end

        arry << query_args

        subquery_args << arry
        filter_args << query_args.last
      else
        filter_args = query_args
      end

      [subquery_args, filter_args]
    end

    # def remove_empty(args)
    #   updated_args = []

    #   args.each do |arg|
    #     updated_args << arg unless is_empty?(arg)
    #   end

    #   updated_args
    # end

    # def is_empty?(filter)
    #   filter.is_a?(Array) && filter.length == 1 && ["::and", "::or", "inner", "full_outer"].include?(filter.first)
    # end

    def is_subquery_query?(query_args)
      verb, subquery_model_name, subquery_args = self.class.match_verbs(query_args, model_predicate, true)

      verb.gives?(:subquery)
    rescue Magma::QuestionError
      false
    end

    def parent_column_name(model)
      parent_attribute = model.attributes.values.find do |attr|
        attr.is_a?(Magma::ParentAttribute)
      end.column_name
    end

    def get_child_model(query_args)
      model(query_args.first)
    end

    def model(name)
      Magma.instance.get_model(model_predicate.model.project_name, name)
    end

    def create_subquery(join_type, args, parent_model = model_predicate.model, join_table_alias = nil)
      verb, subquery_model_name, subquery_args = self.class.match_verbs(args, model_predicate, true)

      if subquery_model_name.first.is_a?(Array)
        binding.pry
        # Subqueries constructed from FilterPredicates
        #   will already have the model_name removed,
        #   so we stub it back in, here.
        subquery_args = args
        subquery_model_name = [parent_model.model_name.to_s]

        # To construct the right subquery, we need to set the
        #   given model as the child.
        child_model = parent_model
      else
        attribute_name = subquery_model_name.first
        attribute = parent_model.attributes[attribute_name.to_sym]

        raise ArgumentError, "Invalid attribute, #{attribute_name}" if attribute.nil?

        child_model = model(attribute_name)
      end

      original_subquery_args = subquery_args.dup

      stable_subquery_alias = subquery_internal_alias_name
      derived_table_alias = derived_table_alias_name(args)

      subquery_filters = []
      while subquery_args.first.is_a?(Array)
        filter_args = subquery_args.shift
        subquery_filter = FilterPredicate.new(@question, child_model, stable_subquery_alias, *filter_args)

        unless subquery_filter.reduced_type == TrueClass
          raise ArgumentError,
            "Filter #{subquery_filter} does not reduce to Boolean #{subquery_filter.argument} #{subquery_filter.reduced_type}!"
        end

        subquery_filters << subquery_filter
      end

      subquery_class = join_type == "inner" ?
        Magma::SubqueryInner :
        Magma::SubqueryOuter

      join_column_name = "id"
      if !join_table_alias && model_predicate.model == child_model
        # No parent was passed in, so we'll join on the model_predicate.model
        # Same table, join is on the parent_column_name
        join_column_name = parent_column_name(child_model)
      end

      model_predicate.add_subquery(subquery_class.new(
        subquery_model: child_model,
        derived_table_alias: derived_table_alias,
        main_table_alias: join_table_alias || model_predicate.alias_name,
        main_table_join_column_name: join_column_name,
        child_table_alias: stable_subquery_alias,
        fk_column_name: parent_column_name(child_model),
        filters: subquery_filters,
        condition: subquery_args.shift,  # the condition, i.e. ::every or ::any))
      ))

      if is_subquery_query?(original_subquery_args) &&
         !original_subquery_args.first.is_a?(Array) &&
         original_subquery_args.first != subquery_model_name.first
        # This must be another model subquery that we have to join in
        # Do this after adding the parent subquery so that
        #   its derived tables is already declared.
        create_subquery(join_type, original_subquery_args, child_model, derived_table_alias)
      end
    end

    def derived_table_alias_name(query_args)
      # Must be calculatable from a given set of query_args
      Digest::SHA256.hexdigest(JSON.generate(query_args))
    end

    def subquery_internal_alias_name
      # Don't memoize this because we need different values
      #   for any nested sub-queries.
      10.times.map { (97 + rand(26)).chr }.join.to_sym
    end
  end
end
