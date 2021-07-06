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

      subquery_class Magma::SubqueryOuter

      constraint do
        or_constraint( 
          @filters.map do |filter|
            filter.flatten.map(&:constraint).concat(
              filter.flatten.map(&:subquery_constraints)).flatten
          end.concat(subquery_constraints).flatten.compact
        )
      end
    end

    verb '::and' do
      child :create_filters

      join :join_filters

      subquery_class Magma::SubqueryInner

      constraint do
        and_constraint( 
          @filters.map do |filter|
            filter.flatten.map(&:constraint).concat(
              filter.flatten.map(&:subquery_constraints)).flatten
          end.concat(subquery_constraints).flatten.compact
        )
      end
    end

    verb '::any' do
      subquery :join_subqueries
    end

    verb '::every' do
      subquery :join_subqueries
    end

    verb do
      child do
        # Check for and create subqueries here
        if Magma::SubqueryUtils.is_subquery_query?(self, @query_args)
          subquery = SubqueryFilter.new(
            predicate: self,
            question: @question,
            model_alias_name: @alias_name,
            join_class: @parent_filter ? @parent_filter.subquery_class : Magma::SubqueryInner,
            query_args: @query_args)

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

    def subquery_class
      @verb.do(:subquery_class)
    end
  end
end
