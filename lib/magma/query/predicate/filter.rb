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
        require 'pry'
        binding.pry
      end
    end

    verb '::and' do
    end
  end
end
