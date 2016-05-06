class Magma
  class Payload
    # The payload is ONLY responsible for retrieving
    # information from the model and turning it into JSON. It
    # should not retrieve any data directly (except perhaps by
    # invoking uncomputed model associations). Ideally all of
    # the data is loaded already when passed into the payload.
    def initialize
      @template_payloads = {}
    end

    def add_model model, columns=nil
      return if @template_payloads[model]

      @template_payloads[model] = TemplatePayload.new(model,columns)
      model.assoc_models.each do |assoc_model|
        add_model assoc_model
      end
    end
    
    def add_records model, records
      @template_payloads[model].add_records records

      records.each do |record|
        record.assoc_records.each do |model,records|
          add_records model, records
        end
      end
    end

    attr_reader :template_payloads

    private

    class TemplatePayload
      def initialize model, columns
        @model = model
        @columns = columns
        @records = []
      end

      attr_reader :records

      def add_records records
        @records.concat records
      end

      def to_hash
        {
          template: @model.json_template,
          documents: @records.map(&:json_document)
        }
      end
    end
  end
end
