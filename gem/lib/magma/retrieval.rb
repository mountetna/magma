class Magma
  class Retrieval
    def initialize model_name:, record_names:, attribute_names: nil, collapse_tables: nil
      @model_name = model_name
      @record_names = record_names
      @attribute_names = (attribute_names || []).map(&:to_sym)
      @collapse_tables = collapse_tables

      @errors = []


    end

    def success?
      @errors && @errors.empty?
    end

    def perform
      return error('No model name given') if @model_name.nil?
      return error('No record names given') if @record_names.nil?

      @model = Magma.instance.get_model @model_name
      
      @attributes = @model.attributes.values.select do |att|
        get_attribute?(att) || show_table_attribute?(att)
      end.map(&:name)

      records = @model.eager(
        @attributes.map(&:eager).compact
      ).where(
        @model.identity => @record_names
      ).all

      @payload = Magma::Payload.new
      @payload.add_model(@model, @attributes)
      @payload.add_records( @model, records)
    end

    attr_reader :payload, :errors

    private

    def error msg
      @errors.push msg
    end

    def show_table_attribute? att
      if @collapse_tables
        att.is_a?(Magma::TableAttribute) ? nil : true
      else
        nil
      end
    end

    def get_attribute? att
      if @attribute_names.empty?
        nil
      else
        @attribute_names.include? att.name
      end
    end
  end
end
