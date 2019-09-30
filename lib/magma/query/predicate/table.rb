class Magma
  # just like the ModelPredicate, this keeps track of its own predicate chain.
  # Confusing... Perhaps a better concept is in order?
  class TablePredicate < Magma::Predicate
    def initialize question, model, alias_name, columns, *query_args
      super(question)
      @model = model
      @alias_name = alias_name
      raise ArgumentError, 'No columns were requested!' if columns.empty?
      @column_predicates = columns.map do |column_query|
        # now, we merely map this to a record predicate. Handy!
        RecordPredicate.new(@question, @model, @alias_name, *column_query)
      end
      process_args(query_args)
    end

    verb nil do
      child Array
    end

    def constraint
      # all constraints will end up with joins below
      []
    end

    def extract table, identity
      @column_predicates.map do |pred|
        pred.extract(table,identity)
      end
    end

    def format
      @column_predicates.map do |pred|
        pred.format
      end
    end

    def join
      constraints = @column_predicates.map do |column|
        column.flatten.map(&:constraint).inject(&:+) || []
      end.inject(&:+) || []

      constraints = constraints.group_by(&:table_alias)

      joins = @column_predicates.map do |pred|
        pred.flatten.map(&:join).inject(&:+)
      end.inject(&:+)

      joins.each do |join|
        join_constraints = constraints[join.right_table_alias]

        join.constraints.concat(join_constraints.map(&:conditions).inject(&:+)) if join_constraints
      end


      joins
    end

    def select
      @column_predicates.map do |pred|
        pred.flatten.map(&:select).inject(&:+)
      end.inject(&:+)
    end
  end
end
