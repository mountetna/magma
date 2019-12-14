class Magma
  class RecordSet < Array
    def initialize(model, loader)
      @model = model
      @loader = loader
      @attribute_entries = {}
    end

    def identifier_id
      @identifier_id ||= Hash[@model.select_map([@model.identity, :id])]
    end

    def attribute_entry(att_name, value)
      attribute_entries(att_name).entry(value)
    end

    def validate(document)
      @loader.send(:validate,@model,document) do |error|
        yield error
      end
    end

    private

    def attribute_entries(att_name)
      @attribute_entries[att_name] ||= @model.attributes[att_name].entry.new(
        @model, @model.attributes[att_name], @loader
      )
    end
  end
end
