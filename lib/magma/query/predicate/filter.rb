class Magma
  class FilterPredicate < Magma::Predicate
    attr_reader :model

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

      join :join_filters_and_subqueries

      constraint do
        or_constraint( 
          @filters.map do |filter|
            filter.flatten.map(&:constraint)
          end.flatten
        ) if  has_constraints?
      end
    end

    verb '::and' do
      child :create_filters

      join :join_filters_and_subqueries

      constraint do
        and_constraint( 
          @filters.map do |filter|
            filter.flatten.map(&:constraint)
          end.flatten
        ) if has_constraints?
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
        # Check for and create subqueries here, instead of
        #   RecordPredicates
        if Magma::SubqueryUtils.is_subquery_query?(self, @query_args)
          # Figure out how to deal with ::and and ::or later
          subquery = SubqueryPredicate.new(self, @question, @alias_name, 'inner', *@query_args)

          @subqueries << subquery

          subquery
        else
          RecordPredicate.new(@question, @model, @alias_name, *@query_args)
        end
      end
    end

    def has_arguments?
      @arguments.length > 0
    end

    private

    def has_constraints?
      @filters.map do |filter|
        filter.flatten.map(&:constraint)
      end.flatten.length > 0
    end
  end
end
