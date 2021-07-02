class Magma
  class FilterPredicate < Magma::Predicate
    def initialize question, model, alias_name, *query_args
      super(question)

      @model = model
      @alias_name = alias_name
      process_args(query_args)
    end

    def create_filters
      invalid_argument!(@query_args.join(', ')) unless @query_args.all?{|q| q.is_a?(Array)}

      @filters = @query_args.map do |args|
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

    verb '::any' do
      subquery do
        yield @subqueries
      end
    end

    verb '::every' do
      subquery do 
        yield @subqueries
      end
    end

    verb do
      child do
        binding.pry
        # Check for and create subqueries here, instead of
        #   RecordPredicates
        if Magma::SubqueryUtils.is_subquery_query?(self, @query_args)
          # Figure out how to deal with ::and and ::or later
          SubqueryPredicate.new(@question, @model, @alias_name, 'inner', *@query_args)
        else
          RecordPredicate.new(@question, @model, @alias_name, *@query_args)
        end
      end
    end
  end
end
