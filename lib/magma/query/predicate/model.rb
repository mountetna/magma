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

    def initialize(model, *predicates)
      @model = model
      @filters = []

      # Since we are shifting off the the first elements on the predicates array
      # we look to see if the first element is an array itself. If it is then we
      # add it to the filters.
      while predicates.first.is_a?(Array)

        filter = RecordPredicate.new(@model, alias_name, *predicates.shift)

        err_msg = "Filter #{filter} does not reduce to Boolean "
        err_msg += "#{filter.argument} #{filter.reduced_type}!"
        raise ArgumentError, err_msg unless filter.reduced_type == TrueClass

        @filters.push(filter)
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
      [ Sequel[alias_name][@model.identity].as(identity) ]
    end

    def constraint 
      @filters.map do |filter|
        filter.flatten.map(&:constraint).inject(&:+) || []
      end.inject(&:+) || []
    end

    def extract(table, return_identity)
      case @argument
      when "::first"
        # after me there might be either a column OR another
        # model it is up to the model to construct a list or
        # return a single item as it sees fit
        # 
        # '::all' returns a list of identifier-value pairs for
        # all identifiers for THIS model
        #
        # '::first' returns a SINGLE value - no identifier required
        super(
          table.group_by do |row|
            row[identity]
          end.first.last,
          identity
        )
      when "::all"
        table.group_by do |row|
          row[identity]
        end.map do |identifier,rows|
          [ identifier, super(rows, identity) ]
        end
      else
        invalid_argument!(@argument)
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

    def identity
      :"#{alias_name}_#{@model.identity}"
    end

    private

    def get_child
      @argument = @predicates.shift

      invalid_argument! unless @argument

      case @argument
      when "::first", "::all"
        return RecordPredicate.new(@model, alias_name, *@predicates)
      else
        invalid_argument!(@argument)
      end
    end
  end
end
