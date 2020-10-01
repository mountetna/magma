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

    def initialize(question, model, *query_args)
      super(question)
      @model = model
      @filters = []

      if question.restrict?
      # the model can be restricted, and we should withhold restricted data
        restriction_model = model
        ancestral_path = []
        while restriction_model do
          if restriction_model.has_attribute?(:restricted)
            query_args.unshift(
              ancestral_path + [ 'restricted', '::untrue' ]
            )
          end
          ancestral_path << restriction_model.parent_model_name&.to_s
          restriction_model = restriction_model.parent_model
        end
      end

      # Since we are shifting off the the first elements on the query_args array
      # we look to see if the first element is an array itself. If it is then we
      # add it to the filters.
      while query_args.first.is_a?(Array)
        filter = RecordPredicate.new(@question, @model, alias_name, *query_args.shift)

        err_msg = "Filter #{filter} does not reduce to Boolean "
        err_msg += "#{filter.argument} #{filter.reduced_type}!"
        raise ArgumentError, err_msg unless filter.reduced_type == TrueClass

        @filters.push(filter)
      end

      process_args(query_args)
    end

    verb '::first' do
      child :record_child
      extract do |table,return_identity|
        child_extract(
          table.group_by do |row|
            row[identity]
          end.first.last,
          identity
        )
      end
      format do
        child_format
      end
    end

    verb '::all' do
      child :record_child
      extract do |table,return_identity|
        table.group_by do |row|
          row[identity]
        end.map do |identifier,rows|
          next unless identifier
          [ identifier, child_extract(rows, identity) ]
        end.compact
      end
      format do
        [
          default_format,
          child_format
        ]
      end
    end

    verb '::any' do
      child TrueClass
      extract do |table,return_identity|
        table.any? do |row|
          row[identity]
        end
      end
      format { 'Boolean' }
    end

    verb '::count' do
      child Numeric
      extract do |table,return_identity|
        table.count do |row|
          row[identity]
        end
      end
      format { 'Numeric' }
    end

    def record_child
      RecordPredicate.new(@question, @model, alias_name, *@query_args)
    end

    def join
      @filters.map do |filter|
        filter.flatten.map(&:join).inject(&:+) || []
      end.inject(&:+) || []
    end

    def select
      [ column_name.as(identity) ]
    end

    def column_name(attribute = @model.identity)
      if attribute.is_a?(String) || attribute.is_a?(Symbol)
        attribute = @model.attributes[attribute.to_sym]
        if attribute.nil?
          attribute = @model.identity
        end
      end

      Sequel[alias_name][attribute.column_name]
    end

    def constraint
      @filters.map do |filter|
        filter.flatten.map(&:constraint).inject(&:+) || []
      end.inject(&:+) || []
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
      alias_for_column(@model.identity.column_name)
    end

    def alias_for_column(column_name)
      :"#{alias_name}_#{column_name}"
    end

    def alias_for_attribute(attr)
      if attr.is_a?(String) || attr.is_a?(Symbol)
        attr = @model.attributes[attr.to_sym]
        if attr.nil?
          return identity
        end
      end

      alias_for_column(attr.column_name)
    end
  end
end
