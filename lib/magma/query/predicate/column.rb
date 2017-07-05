class Magma
  class ColumnPredicate < Magma::Predicate
    # This Predicate returns an actual attribute value of some kind - a number, integer, etc.,
    # or else a test on that value (number > 2, etc.)
    def initialize model, alias_name, attribute_name, argument=nil, *predicates
      @model = model
      @alias_name = alias_name
      @attribute_name = attribute_name
      @argument = argument
      @predicates = predicates
      @child_predicate = get_child
    end

    def extract table, identity
      table.first[column_name]
    end

    def select
      @argument.nil? ? [ Sequel[alias_name][@attribute_name].as(column_name) ] : []
    end

    protected

    def column_name
      :"#{alias_name}_#{@attribute_name}"
    end
  end
end
