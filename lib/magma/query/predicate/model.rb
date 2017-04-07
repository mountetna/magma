class Magma
  class ModelPredicate < Magma::Predicate
    # Model predicate - this is what the query will start with, probably
    #
    # "sample"
    #
    # This is a request for all objects of type "sample", so it's return type should be:
    #   [ Sample ]
    # 

    # This object takes several arguments:
    #   1) It can accept an arbitrary list of filters, which are
    #      in the form of lists, e.g.:
    #
    #      [ "patient", "experiment", "name", "::equals", "Colorectal" ]
    #      [ "patient", "clinical", "parameter", [ "name", "::equals", "Gender" ], "::first", "value", "::equals", "Male" ]
    #
    #      Each one of these filters must reduce to a Boolean, or else it is
    #      invalid.  They must come first.
    #
    #   2) It can be reduced by a list operator. The list operators are:
    #      ::any - a Boolean that returns true if the list is non-zero
    #      ::first - returns the first item in the list, namely a Model
    #      ::all - returns every item in the list, represented by a Model
    #      ::count - returns the number of items in the list

    attr_reader :model

    def initialize model, *predicates
      @model = model.is_a?(Magma::Model) ? model : Magma.instance.get_model(model)
      @filters = []

      while predicates.first.is_a?(Array)
        filter = RecordPredicate.new(@model, *predicates.shift)
        raise ArgumentError, "Filter #{filter} does not reduce to TrueClass #{filter.argument} #{filter.reduced_type}!" unless filter.reduced_type == TrueClass
        @filters.push filter
      end

      @predicates = predicates
      @child_predicate = get_child
    end

    def join
      @filters.map do |filter|
        filter.flatten.map(&:join).inject(&:+) || []
      end.inject(&:+) || []
    end

    def select
      [ :"#{identity}___#{identity}" ]
    end

    def constraint 
      @filters.map do |filter|
        filter.flatten.map(&:constraint).inject(&:+) || []
      end.inject(&:+) || []
    end

    def extract table, return_identity

      case @argument
      when "::first"
        super(
          table.group_by do |row|
            row[identity]
          end.first.last,
          return_identity
        )
      when "::all"
        table.group_by do |row|
          row[identity]
        end.map do |identity,rows|
          super(rows, return_identity)
        end.inject(&:+)
      else
        invalid_argument! @argument
      end
    end

    def to_hash
      super.merge(
        model: model,
        filters: @filters.map do |filter|
          filter.flatten.map do |pred|
            pred.to_hash
          end
        end
      )
    end

    private

    def identity
      :"#{@model.table_name}__#{@model.identity}"
    end

    def get_child
      @argument = @predicates.shift

      invalid_argument! unless @argument

      case @argument
      when "::first", "::all"
        return RecordPredicate.new(@model, *@predicates)
      else
        invalid_argument! @argument
      end
    end
  end
end
