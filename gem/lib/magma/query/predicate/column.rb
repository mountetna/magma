class Magma
  class ColumnPredicate < Magma::Predicate
    def initialize model, attribute_name, argument=nil, *predicates
      @model = model
      @attribute_name = attribute_name
      @argument = argument
      @predicates = predicates
      @child_predicate = get_child
    end

    def extract table, identity
      table.map do |row|
        [
          row[identity],
          row[column_name]
        ]
      end
    end

    def select
      @argument.nil? ? [ :"#{column_name}___#{column_name}" ] : []
    end

    protected

    def column_name
      :"#{@model.table_name}__#{@attribute_name}"
    end
  end
end
