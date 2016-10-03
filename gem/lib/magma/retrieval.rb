class Magma
  class Retrieval
    def initialize model_name:, record_names:, attributes: nil, collapse_tables: nil
      @model_name = model_name
      @record_names = record_names
      @attributes = attributes
      @collapse_tables = collapse_tables
    end

    def to_json
      # Find the model
      @model = Magma.instance.get_model @params["model_name"]

      @attributes = @model.attributes.values.select do |att|
        (@params["attributes"] ? @params["attributes"].include?(att.name.to_s) : true)  &&
        (@params["hide_tables"] ? !att.is_a?(Magma::TableAttribute) : true)
      end.map(&:name)

      @records = @model.retrieve(*@params["record_names"]) do |att|
        @attributes.include?(att.name)
      end.all

      payload = Magma::Payload.new
      payload.add_model(@model, @attributes)

      payload.add_records(@model, @records)
    end
  end
end
