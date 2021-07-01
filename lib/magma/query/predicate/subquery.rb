require "digest"
require "json"

class Magma
  class SubqueryPredicateUtils
    # Subquery predicate utils - this helps manage the creation
    #     of subqueries for ModelPredicates, when
    #     any of the following list operators are used:
    #
    #      ::any - a Boolean that returns true if the list is non-zero
    #      ::every - a Boolean that returns true if every item in the list is non-zero

    attr_reader :model_predicate

    def initialize(model_predicate, question)
      @question = question
      @model_predicate = model_predicate
    end

    def partition_args(query_args, preceding_predicate = "::and")
      subquery_args = []
      filter_args = []

      query_args.each do |args|
        if args.is_a?(Array) && is_subquery_query?(args)
          arry = []

          # BLAH, what is better than this?
          if preceding_predicate == "::or"
            arry << "full_outer"
          elsif preceding_predicate == "::and"
            # Inner join automatically applies an "AND"
            #   effect with subsequent filters.
            arry << "inner"
          end

          arry << args

          subquery_args << args
        else
          preceding_predicate = args
          filter_args << args
        end
      end

      [remove_empty(subquery_args), remove_empty(filter_args)]
    end

    def remove_empty(args)
      updated_args = []

      args.each do |arg|
        updated_args << arg unless is_empty?(arg)
      end

      updated_args
    end

    def is_empty?(filter)
      filter.is_a?(Array) && filter.length == 1 && ["::and", "::or", "inner", "full_outer"].include?(filter.first)
    end

    def is_subquery_query?(query_args)
      # Super hacky, too...
      ["::any", "::every"].include?(query_args.last)
      # verb, subquery_model_name, subquery_args = model_predicate.class.match_verbs(query_args, model_predicate, true)

      # verb.gives?(:subquery)
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
      verb, subquery_model_name, subquery_args = model_predicate.class.match_verbs(args, model_predicate, true)

      attribute_name = subquery_model_name.first
      attribute = parent_model.attributes[attribute_name.to_sym]

      raise ArgumentError, "Invalid attribute, #{attribute_name}" if attribute.nil?

      child_model = model(attribute_name)

      original_subquery_args = subquery_args.dup

      subquery_alias = subquery_internal_alias_name
      derived_table_alias = derived_table_alias_name(args)

      subquery_filters = []
      while subquery_args.first.is_a?(Array)
        filter_args = subquery_args.shift
        subquery_filter = FilterPredicate.new(@question, child_model, subquery_alias, *filter_args)

        unless subquery_filter.reduced_type == TrueClass
          raise ArgumentError,
            "Filter #{subquery_filter} does not reduce to Boolean #{subquery_filter.argument} #{subquery_filter.reduced_type}!"
        end

        subquery_filters << subquery_filter
      end

      model_predicate.add_subquery(Magma::Subquery.new(
        parent_model,
        child_model,
        derived_table_alias,
        join_table_alias || model_predicate.alias_name,
        subquery_alias,
        parent_column_name(child_model),
        subquery_filters,
        subquery_args.shift,  # the condition, i.e. ::every or ::any
        join_type
      ))

      if is_subquery_query?(original_subquery_args) &&
         !original_subquery_args.first.is_a?(Array) &&
         original_subquery_args.first != subquery_model_name
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
