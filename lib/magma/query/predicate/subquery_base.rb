class Magma
  class SubqueryPredicateBase < Magma::Predicate
    attr_reader :predicate, :subqueries, :subquery_class

    def initialize(predicate:, question:, model_alias_name:, query_args:, subquery_class: Magma::SubqueryInner)
      super(question)

      @predicate = predicate
      @model_alias_name = model_alias_name
      @subquery_class = subquery_class

      create_subqueries(query_args)
    end

    def reduced_type
      TrueClass
    end

    private

    def parent_column_name(model)
      parent_attribute = model.attributes.values.find do |attr|
        attr.is_a?(Magma::ParentAttribute)
      end.column_name
    end

    def subquery_filters(subquery_args, internal_table_alias, subquery_model)
      subquery_filters = []
      while subquery_args.first.is_a?(Array) && !Magma::SubqueryUtils.is_subquery?(predicate, subquery_args.first)
        filter_args = subquery_args.shift
        subquery_filter = FilterPredicate.new(
          question: @question,
          model: subquery_model,
          alias_name: internal_table_alias,
          query_args: filter_args,
        )

        unless subquery_filter.reduced_type == TrueClass
          raise ArgumentError,
            "Filter #{subquery_filter} does not reduce to Boolean #{subquery_filter.argument} #{subquery_filter.reduced_type}!"
        end

        subquery_filters << subquery_filter
      end

      subquery_filters
    end

    def random_alias_name
      # Don't memoize this because we need different values
      #   for any nested sub-queries.
      10.times.map { (97 + rand(26)).chr }.join.to_sym
    end

    def create_subqueries(args)
      raise Exception, "Must implement this method in subclasses."
    end
  end
end
