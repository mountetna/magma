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

      def to_s
        { table1_column => table2_column }.to_s
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
    class Constraint
      attr_reader :conditions
      def initialize *args
        @conditions = args
      end

      def apply query
        query.where(*@conditions)
      end

      def to_s
        @conditions.to_s
      end

      def hash
        @conditions.hash
      end

      def eql? other
        @conditions == other.conditions
      end
    end

    def initialize predicates, options = {}
      @start_predicate = ModelPredicate.new(*predicates)
      @model = @start_predicate.model
      @options = options
    end

    def answer
      table = to_table

      @start_predicate.extract(table,identity)
    end

    def model
      @start_predicate.model
    end

    def predicates
      @predicates ||= @start_predicate.flatten
    end

    def identity
      :"#{@model.table_name}__#{@model.identity}"
    end

    def type
      @start_predicate.reduced_type
    end

    def to_predicates
      predicates.map do |pred|
        pred.to_hash
      end
    end

    def to_sql
      query = @model.order(@model.identity)

      predicate_collect(:join).uniq.each do |join|
        query = join.apply(query)
      end

      predicate_collect(:constraint).uniq.each do |constraint|
        query = constraint.apply(query)
      end

      query = query.select( 
        *(predicate_collect(:select) + [ :"#{identity}___#{identity}" ]).uniq
      )

      query.sql
    end

    def to_table
      Magma.instance.db[
        to_sql
      ].all
    end
    private

    def predicate_collect type
      predicates.map(&type).inject(&:+) || []
    end


  end
end

