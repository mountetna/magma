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
      @subquery = nil

      # Since we are shifting off the the first elements on the query_args array
      # we look to see if the first element is an array itself. If it is then we
      # add it to the filters.
      binding.pry
      while query_args.first.is_a?(Array)
        # If any conditional verbs are present, we need to
        #   actually create a subquery to SELECT from, instead of
        #   a SQL WHERE clause.
        args = query_args.shift
        if is_subquery_query?(args)
          create_subquery(args)
        else
          create_filter(args)
        end
      end

      add_filters

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

      subquery do
        yield @subquery if has_subquery?
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
        yield @subquery if has_subquery?
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
      return [@subquery] if has_subquery?

      []
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

    def is_subquery_query?(query_args)

      verb, subquery_model_name, subquery_args = self.class.match_verbs(query_args, self, true)

      verb.gives?(:subquery)
    rescue Magma::QuestionError
      false
    end

    def create_subquery(args)
      verb, subquery_model_name, subquery_args = self.class.match_verbs(args, self, true)
      attribute_name = subquery_model_name.first
      attribute = @model.attributes[attribute_name.to_sym]

      raise ArgumentError, "Invalid attribute, #{attribute_name}" if attribute.nil?

      child_model = Magma.instance.get_model(@model.project_name, attribute_name)
      
      subquery_filters = []
      while subquery_args.first.is_a?(Array)
        filter_args = subquery_args.shift
        subquery_filter = FilterPredicate.new(@question, child_model, child_table_alias, *filter_args)
  
        unless subquery_filter.reduced_type == TrueClass
          raise ArgumentError,
            "Filter #{subquery_filter} does not reduce to Boolean #{subquery_filter.argument} #{subquery_filter.reduced_type}!"
        end
        
        subquery_filters << subquery_filter
      end
      
      parent_attribute = child_model.attributes.values.select do |attr|
        attr.is_a?(Magma::ParentAttribute)
      end.first

      @subquery = Magma::Subquery.new(
        @model,
        child_model,
        derived_table_alias,
        alias_name,
        child_table_alias,
        parent_attribute.column_name,
        subquery_filters,
        subquery_args.shift  # the condition, i.e. ::every or ::any
      )
    end

    private

    def has_subquery?
      !@subquery.nil?
    end

    def derived_table_alias
      "derived_#{alias_name}".to_sym
    end

    def child_table_alias
      "#{alias_name}_child".to_sym
    end
  end
end
