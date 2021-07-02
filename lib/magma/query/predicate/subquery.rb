require "digest"
require "json"

class Magma
  class SubqueryPredicate < Magma::Predicate
    # SubqueryPredicate should be a simple
    #   wrapper around SubqueryInner and SubqueryOuter
    attr_reader :predicate, :subquery

    def initialize(predicate, question, model_alias_name, join_type, *query_args)
      super(question)

      @predicate = predicate
      @model_alias_name = model_alias_name
      @join_type = join_type

      process_args(query_args)
    end

    def reduced_type
      TrueClass
    end

    verb do
      subquery do
        # How to access @subquery?
        binding.pry
        puts "blah"
      end

      child do

        # Nested subqueries would go here?
        binding.pry
        SubqueryPredicate.new(predicate, @question, alias_name, @join_type, *@query_args)
      end
    end

    def process_args(query_args)
      @subquery = create_subquery(@join_type, query_args, predicate.model, @model_alias_name)
    end

    def parent_column_name(model)
      parent_attribute = model.attributes.values.find do |attr|
        attr.is_a?(Magma::ParentAttribute)
      end.column_name
    end

    def model(project_name, name)
      Magma.instance.get_model(project_name, name)
    end

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
        condition: subquery_args.last,  # the condition, i.e. ::every or ::any
      )
    end

    def subquery_filters(subquery_args, internal_table_alias, subquery_model)
      subquery_filters = []
      while subquery_args.first.is_a?(Array)
        filter_args = subquery_args.shift
        subquery_filter = FilterPredicate.new(@question, subquery_model, internal_table_alias, *filter_args)

        unless subquery_filter.reduced_type == TrueClass
          raise ArgumentError,
            "Filter #{subquery_filter} does not reduce to Boolean #{subquery_filter.argument} #{subquery_filter.reduced_type}!"
        end

        subquery_filters << subquery_filter
      end

      subquery_filters
    end

    def create_subquery(join_type, args, parent_model = predicate.model, join_table_alias = nil)
      verb, subquery_model_name, subquery_args = predicate.class.match_verbs(args, predicate, true)

      if subquery_model_name.first.is_a?(Array)
        # This is a boolean subquery. Returns directly true / false.
        # Will never have a child / nested subquery.
        create_boolean_subquery(parent_model.model_name.to_s, args, parent_model)
      else
        # This is part of a Filter, so more complicated
        attribute_name = subquery_model_name.first
        attribute = parent_model.attributes[attribute_name.to_sym]

        raise ArgumentError, "Invalid attribute, #{attribute_name}" if attribute.nil?

        child_model = model(parent_model.project_name, attribute_name)

        original_subquery_args = subquery_args.dup

        internal_table_alias = subquery_internal_alias_name
        subquery_class = join_type == "inner" ?
          Magma::SubqueryInner :
          Magma::SubqueryOuter

        subquery_class.new(
          subquery_model: child_model,
          derived_table_alias: derived_table_alias_name(args),
          main_table_alias: join_table_alias || predicate.alias_name,
          main_table_join_column_name: "id",
          internal_table_alias: internal_table_alias,
          fk_column_name: parent_column_name(child_model),
          filters: subquery_filters(subquery_args, internal_table_alias, child_model),
          condition: subquery_args.last,  # the condition, i.e. ::every or ::any))
        )
        # if Magma::SubqueryUtils.is_subquery_query?(predicate, original_subquery_args) &&
        #    !original_subquery_args.first.is_a?(Array) &&
        #    original_subquery_args.first != subquery_model_name.first
        #   # This must be another model subquery that we have to join in
        #   # Do this after adding the parent subquery so that
        #   #   its derived tables is already declared.
        #   create_subquery(join_type, original_subquery_args, child_model, derived_table_alias)
        # end
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
