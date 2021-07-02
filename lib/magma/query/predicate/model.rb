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
    #      ::every - a Boolean that returns true if every item in the list is non-zero

    attr_reader :model

    def each_ancestor
      current_model = @model
      ancestral_path = []
      while current_model do
        yield current_model, ancestral_path
        ancestral_path << current_model.parent_model_name&.to_s
        current_model = current_model.parent_model
      end
    end

    def initialize(question, model, *query_args)
      super(question)
      @model = model
      @filters = []

      # We'll also need the preceding filter "verb" to correctly
      #   determine the subquery type????
      binding.pry
      subquery_args, filter_args = Magma::SubqueryUtils.partition_args(self, query_args)

      subquery_args.each do |join_type, args|
        create_subquery(join_type, args)
      end

      # Any remaining elements should be Filters.
      # Since we are shifting off the the first elements on the query_args array
      # we look to see if the first element is an array itself. If it is then we
      # add it to the filters.
      while filter_args.first.is_a?(Array)
        create_filter(filter_args.shift)
      end

      add_filters

      process_args(filter_args)
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

      subquery do
        yield @subqueries
      end

      extract do |table,return_identity|
        table.any? do |row|
          row[identity]
        end
      end
      format { 'Boolean' }
    end

    verb '::every' do
      child TrueClass

      subquery do 
        yield @subqueries
      end

      extract do |table,return_identity|
        table.length > 0 && table.all? do |row|
          row[identity]
        end
      end
      format { 'Boolean' }
    end

    verb '::count' do
      child Numeric
      extract do |table,return_identity|
        table.uniq do |row|
          row[identity]
        end.count do |row|
          row[identity]
        end
      end
      format { 'Numeric' }
    end

    def create_filter(args)
      filter = FilterPredicate.new(@question, @model, alias_name, *args)

      unless filter.reduced_type == TrueClass
        raise ArgumentError,
          "Filter #{filter} does not reduce to Boolean #{filter.argument} #{filter.reduced_type}!"
      end

      @filters.push(filter)
    end

    def create_subquery(join_type, args)
      subquery = SubqueryPredicate.new(self, @question, alias_name, join_type, *args)

      @subqueries.push(subquery)
    end

    def add_filters
      if @question.restrict?
      # the model can be restricted, and we should withhold restricted data
        each_ancestor do |restriction_model, ancestors|
          if restriction_model.has_attribute?(:restricted)
            create_filter(ancestors + [ 'restricted', '::untrue' ])
          end
        end
      end
    end

    def record_child
      RecordPredicate.new(@question, @model, alias_name, *@query_args)
    end

    def join
      join_filters
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

    def subquery
      inject_subqueries
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
