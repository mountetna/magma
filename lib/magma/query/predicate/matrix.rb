require 'set'

class Magma
  class MatrixPredicate < Magma::Predicate
    attr_reader :attribute
    def initialize question, model, alias_name, attribute, *query_args
      super(question)
      @model = model
      @alias_name = alias_name
      @attribute = attribute
      @attribute_name = attribute.name.to_sym
      @column_name = attribute.column_name.to_sym
      @requested_identifiers = Set.new
      process_args(query_args)
    end

    verb '::slice', Array do
      child Array

      extract do |table, identity|
        @requested_identifiers << table.first[identity]
        MatrixValue.new(self, table.first[identity], @arguments[1])
      end
      validate do |_, validation_list|
        (validation_list - @predicate.attribute.validation_object.options).empty? && !validation_list.empty?
      end
      format { [ default_format, @arguments[1] ] }
    end

    verb nil do
      child Array

      extract do |table, identity|
        @requested_identifiers << table.first[identity]
        MatrixValue.new(self, table.first[identity])
      end
      format { [ default_format, @attribute.validation_object.options ] }
    end

    def select
      []
    end

    def matrix_row(identifier, column_names)
      ensure_requested_identifiers
      @attribute.matrix_row_json(identifier, column_names)
    end

    protected

    def column_name
      :"#{alias_name}_#{@column_name}"
    end

    def ensure_requested_identifiers
      return if @requested_identifiers.empty?
      @attribute.cache_rows(@requested_identifiers)
      @requested_identifiers.clear
    end

    class MatrixValue
      attr_reader :column_names
      def initialize(predicate, identifier, column_names=nil)
        @predicate = predicate
        @identifier = identifier
        @column_names = column_names ? column_names : @predicate.attribute.validation_object.options
      end

      def to_json(options={})
        @predicate.matrix_row(@identifier,@column_names)
      end
    end
  end
end
