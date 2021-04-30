require_relative './query/question'

class Magma
  class Retrieval
    attr_reader :attribute_names
    MAX_PAGE_SIZE=10_000

    def initialize(model, record_names, attribute_names, opts={})
      opts = {
        page_size: MAX_PAGE_SIZE,
        page: 1
      }.merge(opts)

      @filters = opts[:filters] || []
      @collapse_tables = opts[:collapse_tables]
      @page_size = opts[:page_size]
      @page = opts[:page]
      @restrict = opts[:restrict]
      @user = @user
      @order = opts[:order]
      @show_disconnected = opts[:show_disconnected]
      @output_predicates = opts[:output_predicates] || []

      @model = model
      @record_names = record_names

      # the retrieval filters out attributes that are not allowed
      @requested_attribute_names = attribute_names
      @attribute_names = attributes.map(&:name)
    end

    def attributes
      @attributes ||= begin
        attributes = @model.attributes.values.select do |att|
          requested?(att) && !restricted?(att) &&
          !(att.is_a?(Magma::TableAttribute) && @collapse_tables)
        end

        if @requested_attribute_names != "all"
          attributes.sort_by! do |att|
            if att == @model.identity
              -1
            else
              @requested_attribute_names.index(att.name)
            end
          end
        end

        attributes
      end
    end

    def table_attributes
      @table_attributes ||= @model.attributes.values.select do |att|
        att.is_a?(Magma::TableAttribute) && requested?(att) && !restricted?(att)
      end
    end

    def records
      to_records(question.answer)
    end

    def count
      question.count
    end

    def each_page
      question.each_page_answer do |answer|
        yield to_records(answer)
      end
    end

    def output_predicate_for_att(att)
      predicates_list&.find do |predicate|
        predicate.first == att.name.to_s
      end
    end

    private

    def requested?(att)
      # identifiers are always included
      @model.identity == att ||
      # they asked for all attribute_names
      @requested_attribute_names == 'all' ||
      # the attribute was requested by name
      (@requested_attribute_names.is_a?(Array) && @requested_attribute_names.include?(att.name))
    end

    def restricted?(att)
      @restrict && att.restricted
    end

    def to_records(answer)
      answer.map do |name, row|
        Hash[
          @attribute_names.map.with_index do |attribute_name, i|
            attribute_name == :id ?
              [ :id, row[i] ] :
            [ attribute_name, @model.attributes[attribute_name].query_to_payload(row[i]) ]
          end
        ]
      end
    end

    def question
      @question ||= Magma::Question.new(@model.project_name, query, page: @page, page_size: @page_size, restrict: @restrict, order: @order, show_disconnected: @show_disconnected)
    end

    def query
      [
        @model.model_name.to_s,
        *query_filters,
        '::all',
        outputs
      ]
    end

    def query_filters
      list = []
      if @record_names.is_a?(Array)
        list.push [ '::identifier', '::in', @record_names ]
      end

      @filters.each do |filter|
        list.concat(
          filter.apply(attributes)
        )
      end

      list
    end

    def outputs
      attributes.map do |att|
        case att
        when OpenStruct
          [ '::identifier' ]
        when Magma::CollectionAttribute, Magma::TableAttribute
          [ att.name.to_s, '::all', '::identifier' ]
        when Magma::ForeignKeyAttribute, Magma::ChildAttribute
          [ att.name.to_s, '::identifier' ]
        when Magma::FileAttribute, Magma::ImageAttribute, Magma::FileCollectionAttribute
          # Change to ::all because File.query_to_payload
          #   now expects a hash
          [ att.name.to_s, '::all' ]
        when Magma::MatchAttribute
          [ att.name.to_s ]
        when Magma::MatrixAttribute
          # Only return if a ::slice ([]) predicate was passed in
          match = output_predicate_for_att(att)

          match ? match : [ att.name.to_s ]
        else
          [ att.name.to_s ]
        end
      end
    end

    def predicates_list
      @predicates_list ||= @output_predicates.map do |output_predicate|
        output_predicate.apply(attributes)
      end.flatten(1) # Merge all predicates together into a list of output predicates
    end

    class ParentFilter
      def initialize child, parent, parent_ids
        @child = child
        @parent = parent
        raise unless @child.attributes[@child.parent_model_name].link_model == @parent
        @parent_ids = parent_ids
      end

      def apply(attributes)
        [
          [ @child.parent_model_name, '::identifier', '::in', @parent_ids ]
        ]
      end
    end

    class FilterPredicateBase
      def array_or_value(operator, value)
        return value.split(",") if "[]" == operator
        
        value
      end
    end

    class Filter < Magma::Retrieval::FilterPredicateBase
      FILTER_TERM = /^
        ([\w]+)
        (=|<|>|>=|<=|~|\[\]|\^@)
        (.*)
        $/x

      def filter_term term, attributes
        match, att_name, operator, value = term.match(FILTER_TERM).to_a
        raise ArgumentError, "Filter term '#{term}' does not parse" if match.nil?

        att = attributes.find{|a| a.name == att_name.to_sym}
        raise ArgumentError, "#{att_name} is not an attribute" unless att.is_a?(Magma::Attribute)
        
        raise ArgumentError, "Cannot filter on collection attributes" if [ Magma::CollectionAttribute, Magma::TableAttribute ].any? { |a| att.is_a?(a) }

        return [ "::lacks", att_name ] if nil_operator?(operator)

        case att
        when Magma::ForeignKeyAttribute, Magma::ChildAttribute
          return [ att_name, '::identifier', string_op(operator), array_or_value(operator, value) ]
        when Magma::IntegerAttribute, Magma::FloatAttribute
          return [ att_name, numeric_op(operator), value.to_f ]
        when Magma::DateTimeAttribute
          return [ att_name, numeric_op(operator), value ]
        when Magma::StringAttribute
          return [ att_name, string_op(operator), array_or_value(operator, value) ]
        when Magma::BooleanAttribute
          return [ att_name, boolean_op(operator, value) ]
        when Magma::FileAttribute, Magma::ImageAttribute
          return [ att_name, file_op(operator), value ]
        when Magma::MatrixAttribute
          # Since there are no MatrixAttribute filters, we'll
          #   treat anything passed in as a "::has" filter
          #   on the matrix attribute. Any slices have to
          #   be sent as output_predicate values.
          return [ '::has', att_name ]
        else
          raise ArgumentError, "Cannot query for #{att_name}"
        end
      end

      def nil_operator?(operator)
        "^@" == operator
      end

      def file_op operator
        case operator
        when "="
          return "::equals"
        else
          raise ArgumentError, "Invalid operator #{operator} for file attribute!"
        end
      end

      def string_op operator
        case operator
        when "="
          return "::equals"
        when "~"
          return "::matches"
        when "<=", ">=", ">", "<"
          return "::#{operator}"
        when "[]"
          return "::in"
        else
          raise ArgumentError, "Invalid operator #{operator} for string attribute!"
        end
      end

      def numeric_op operator
        case operator
        when "=", "<=", ">=", ">", "<"
          return "::#{operator}"
        else
          raise ArgumentError, "Invalid operator #{operator} for string attribute!"
        end
      end

      def boolean_op operator, value
        raise ArgumentError, "Invalid operator #{operator} for boolean column!" unless operator == "="
        case value
        when "true"
          return "::true"
        when "false"
          return "::false"
        end
      end
    end

    class StringFilter < Magma::Retrieval::Filter
      def initialize filter
        @filter = filter || ""
      end

      def apply(attributes)
        @filter.split(/\s/).map do |term|
          filter_term(term, attributes)
        end.compact
      end
    end

    class JsonFilter < Magma::Retrieval::Filter
      def initialize filters
        @filters = filters || []
      end

      def apply(attributes)
        @filters.map do |term|
          filter_term(term, attributes)
        end.compact
      end
    end

    class OutputPredicate < Magma::Retrieval::FilterPredicateBase
      PREDICATE_TERM = /^
        ([\w]+)
        (\[\])
        (.*)
        $/x

      def predicate_term term, attributes
        match, att_name, operator, value = term.match(PREDICATE_TERM).to_a
        raise ArgumentError, "Predicate term '#{term}' does not parse" if match.nil?

        att = attributes.find{|a| a.name == att_name.to_sym}
        raise ArgumentError, "#{att_name} is not an attribute" unless att.is_a?(Magma::Attribute)

        case att
        when Magma::MatrixAttribute
          return [ att_name, matrix_op(operator), array_or_value(operator, value) ]
        else
          raise ArgumentError, "Cannot submit output predicate for #{att_name}"
        end
      end

      def matrix_op operator
        case operator
        when "[]"
          return "::slice"
        else
          raise ArgumentError, "Invalid operator #{operator} for matrix attribute!"
        end
      end
    end

    class StringOutputPredicate < Magma::Retrieval::OutputPredicate
      def initialize output_predicates
        @output_predicates = output_predicates || ""
      end

      def apply(attributes)
        @output_predicates.split(/\s/).map do |term|
          predicate_term(term, attributes)
        end.compact
      end
    end

    class JsonOutputPredicate < Magma::Retrieval::OutputPredicate
      def initialize output_predicates
        @output_predicates = output_predicates || []
      end

      def apply(attributes)
        @output_predicates.map do |term|
          predicate_term(term, attributes)
        end.compact
      end
    end
  end
end
