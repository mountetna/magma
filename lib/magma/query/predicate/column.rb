class Magma
  class ColumnPredicate < Magma::Predicate
    # This Predicate returns an actual attribute value of some kind - a number, integer, etc.,
    # or else a test on that value (number > 2, etc.)
    def initialize question, model, alias_name, attribute_name, *query_args
      super(question)
      @model = model
      @alias_name = alias_name
      @attribute_name = attribute_name
      process_args(query_args)
    end

    def self.inherited(subclass)
      Magma::Predicate.inherited(subclass)
    end

    def extract table, identity
      table.first[column_name]
    end

    def select
      @arguments.empty? ? [ Sequel[alias_name][@attribute_name].as(column_name) ] : []
    end

    protected

    def column_name
      :"#{alias_name}_#{@attribute_name}"
    end
  end
end
