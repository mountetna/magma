require_relative 'predicate'

class Magma
  class Question
    class Join
      def initialize t1, t1_id, t2, t2_id
        @table1 = t1.to_sym
        @table1_id = t1_id.to_sym
        @table2 = t2.to_sym
        @table2_id = t2_id.to_sym
      end

      def apply query
        query.join(
          @table1,
          table1_column => table2_column
        )
      end

      def table1_column
          :"#{@table1}__#{@table1_id}" 
      end

      def table2_column
          :"#{@table2}__#{@table2_id}"
      end

      def hash
        table1_column.hash + table2_column.hash
      end

      def eql? other
        table1_column == other.table1_column && table2_column == other.table2_column
      end
    end
    class Filter
      def initialize *args
        @arguments = args
      end

      def apply query
        query.where(*@arguments)
      end
    end
    def initialize predicates, options = {}
      @start_predicate = ModelListPredicate.new(*predicates)
      @model = @start_predicate.model
      @options = options
    end

    def answer
      table = to_table

      @start_predicate.extract(table, identity)
    end

    def identity
      :"#{@model.table_name}__#{@model.identity}"
    end

    def type
      @start_predicate.reduced_type
    end

    def to_sql
      query = @model.order(@model.identity)
      joins = @start_predicate.join.uniq
      joins.each do |join|
        query = join.apply(query)
      end
      filters = @start_predicate.filter.uniq
      filters.each do |filter|
        query = filter.apply(query)
      end
      selects = (@start_predicate.select + [ :"#{identity}___#{identity}" ]).uniq
      query = query.select( *selects )

      query.sql
    end

    private

    def to_table
      Magma.instance.db[
        to_sql
      ].all
    end

  end
end

