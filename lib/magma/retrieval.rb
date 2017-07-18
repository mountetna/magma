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
    att_name, operator, value = term.match(FILTER_TERM)
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
