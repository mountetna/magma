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

    # verb '::any' do
    #   child :create_subqueries

    #   subquery do
    #     yield @subqueries
    #   end

    #   format { 'Boolean' }
    # end

    # verb '::every' do
    #   child :create_subqueries

    #   subquery do 
    #     yield @subqueries
    #   end

    #   extract do |table,return_identity|
    #     table.length > 0 && table.all? do |row|
    #       row[identity]
    #     end
    #   end
    #   format { 'Boolean' }
    # end

    verb do
      child do
        RecordPredicate.new(@question, @model, @alias_name, *@query_args)
      end
    end
  end
end
