class Magma
  class ColumnPredicate < Magma::Predicate
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
      @argument.nil? ? [ :"#{column_name}___#{column_name}" ] : []
    end

    protected

    def column_name
      :"#{alias_name}__#{@attribute_name}"
    end
  end
end
