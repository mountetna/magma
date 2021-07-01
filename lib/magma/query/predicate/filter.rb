class Magma
  class FilterPredicate < Magma::Predicate
    def initialize question, model, alias_name, *query_args
      super(question)

      # Also partition here for subqueries and filters?
      @subquery_util = Magma::SubqueryPredicateUtils.new(self, question)

      @model = model
      @alias_name = alias_name
      process_args(query_args)
    end

    def create_filters
      invalid_argument!(@query_args.join(', ')) unless @query_args.all?{|q| q.is_a?(Array)}

      # First, we extract the subquery Arrays from the
      #   query_args and create subqueries for them.
      # These conditional verbs (i.e. ::every, ::any)
      #   result in a subquery to SELECT from, instead
      #   of a SQL WHERE clause.
      binding.pry
      subquery_args, filter_args = @subquery_util.partition_args(@query_args, @arguments.first)

      subquery_args.each do |join_type, args|
        @subquery_util.create_subquery(join_type, args)
      end

      @filters = filter_args.map do |args|
        FilterPredicate.new(@question, @model, @alias_name, *args)
      end

      @query_args = []

      terminal TrueClass
    end

    verb '::or' do
      child :create_filters

      join :join_filters

      constraint do
        or_constraint( 
          @filters.map do |filter|
            filter.flatten.map(&:constraint)
          end.flatten
        )
      end
    end

    verb '::and' do
      child :create_filters

      join :join_filters

      constraint do
        and_constraint( 
          @filters.map do |filter|
            filter.flatten.map(&:constraint)
          end.flatten
        )
      end
    end

    verb do
      child do
        RecordPredicate.new(@question, @model, @alias_name, *@query_args)
      end
    end
  end
end
