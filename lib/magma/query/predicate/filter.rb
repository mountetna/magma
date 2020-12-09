class Magma
  class FilterPredicate < Magma::Predicate
    def initialize question, model, alias_name, *query_args
      super(question)

      @model = model
      @alias_name = alias_name
      process_args(query_args)
    end

    verb '::or' do
      child do
        invalid_argument!(@query_args.join(', ')) unless @query_args.all?{|q| q.is_a?(Array)}

        @filters = @query_args.map do |args|
          FilterPredicate.new(@question, @model, @alias_name, *args)
        end

        TrueClass
      end
    end

    verb '::and' do
      child TrueClass
    end

    verb do
      child do
        RecordPredicate.new(@question, @model, @alias_name, *@query_args)
      end
    end
  end
end
