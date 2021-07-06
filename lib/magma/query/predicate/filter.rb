class Magma
  class FilterPredicate < Magma::Predicate
    attr_reader :model, :arguments

    def initialize question:, model:, alias_name:, query_args:, parent_filter: nil
      super(question)

      @model = model
      @alias_name = alias_name
      @parent_filter = parent_filter
      process_args(query_args)
    end

    def create_filters
      invalid_argument!(@query_args.join(', ')) unless @query_args.all?{|q| q.is_a?(Array)}

      @filters = @query_args.map do |args|
        FilterPredicate.new(
          question: @question,
          model: @model,
          alias_name: @alias_name, 
          parent_filter: self,
          query_args: args)
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
            filter.flatten.map(&:constraint).concat(
              filter.flatten.map(&:subquery_constraints)).flatten
          end.concat(@subqueries.map(&:constraint)).flatten.compact
        )
      end
    end

    verb '::and' do
      child :create_filters

      join :join_filters

      constraint do
        and_constraint( 
          @filters.map do |filter|
            filter.flatten.map(&:constraint).concat(
              filter.flatten.map(&:subquery_constraints)).flatten
          end.concat(@subqueries.map(&:constraint)).flatten.compact
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
        # Check for and create subqueries here, instead of
        #   RecordPredicates
        if Magma::SubqueryUtils.is_subquery_query?(self, @query_args)
          subquery = SubqueryPredicate.new(
            self,
            @question,
            @alias_name,
            Magma::SubqueryUtils.subquery_type(
              @parent_filter&.arguments&.first),
            *@query_args)

          @subqueries << subquery

          subquery
        else
          RecordPredicate.new(@question, @model, @alias_name, *@query_args)
        end
      end
    end

    def subquery
      join_subqueries.concat(join_filter_subqueries)
    end
  end
end
