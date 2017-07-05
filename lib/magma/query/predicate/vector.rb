class Magma
  # just like the ModelPredicate, this keeps track of its own predicate chain.
  # Confusing... Perhaps a better concept is in order?
  class VectorPredicate < Magma::Predicate
    def initialize model, alias_name, columns, *predicates
      @model = model
      @alias_name = alias_name
      @columns = columns
      @predicates = predicates
      @child_predicate = get_child
    end

    def extract table, identity
      table
    end

    def select
      []
    end

    private

    def get_child
      raise ArgumentError, "Column vector cannot be empty!" if @columns.empty?
      raise ArgumentError, "Column vector must have column names!" unless @columns.all?{|c| c.is_a?(Array) && c.length == 2}
      raise ArgumentError, "No duplicate column names!" unless @columns.map(&:first).uniq.length == @columns.length
      @column_predicates = @columns.map do |column_name, column_query|
        # now, we merely map this to a record predicate. Handy!
        RecordPredicate.new(@model, @alias_name, *column_query)
      end
      return terminal(Array)
    end
  end
end
