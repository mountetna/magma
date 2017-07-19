class Retrieval
  attr_reader :attribute_names
  MAX_PAGE_SIZE=10_000

  def initialize model, record_names, attributes, filter="", page=1, page_size=MAX_PAGE_SIZE
    @model = model
    @record_names = record_names
    @attributes = attributes
    @attribute_names = attributes.map(&:name)
    @filter = filter
    @page_size = page_size
    @page = page
  end

  def records
    @records ||= Magma::Question.new(query).answer.map do |name, row|
      Hash[ @attribute_names.zip(row) ].update( @model.identity => name )
    end
  end

  private

  def query
    [
      @model.model_name.to_s,
      *filters,
      '::all',
      outputs
    ]
  end

  def filters
    list = []
    if @record_names.is_a?(Array)
      list.push [ '::identifier', '::in', @record_names ]
    end

    if @filter
      list.concat(
        @filter.split(/\s/).map do |term|
          filter_term(term)
        end.compact
      )
    end

    list
  end

  FILTER_TERM = /^
    ([\w]+)
    (=|<|>|>=|<=|~)
    (.*)
    $/x

  def filter_term term
    match, att_name, operator, value = term.match(FILTER_TERM).to_a
    raise ArgumentError, "Filter term '#{term}' does not parse" if match.nil?

    att = @attributes.find{|a| a.name == att_name.to_sym}
    raise ArgumentError, "#{att_name} is not an attribute" if att.nil?

    case att
    when Magma::CollectionAttribute, Magma::TableAttribute
      raise ArgumentError, "Cannot filter on collection attributes"
    when Magma::ForeignKeyAttribute, Magma::ChildAttribute
      return [ att_name, '::identifier', string_op(operator), value ]
    when Magma::Attribute
      case att.type.name
      when "Integer", "Float", "DateTime"
        return [ att_name, numeric_op(operator), value ]
      when "String"
        return [ att_name, string_op(operator), value ]
      when "TrueClass"
        return [ att_name, boolean_op(operator, value) ]
      else
        raise ArgumentError, "Unknown type for attribute"
      end
    else
      raise ArgumentError, "Cannot query for #{att_name}"
    end
  end

  def string_op operator
    case operator
    when "="
      return "::equals"
    when "~"
      return "::matches"
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

  def outputs
    @attributes.map do |att|
      case att
      when Magma::CollectionAttribute, Magma::TableAttribute
        [ att.name.to_s, '::all', '::identifier' ]
      when Magma::ForeignKeyAttribute, Magma::ChildAttribute
        [ att.name.to_s, '::identifier' ]
      else
        [ att.name.to_s ]
      end
    end
  end
end
