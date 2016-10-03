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

    def add_model model, attributes=nil
      return if @template_payloads[model]

      @template_payloads[model] = TemplatePayload.new(model,attributes)
      model.assoc_models(attributes).each do |assoc_model|
        add_model assoc_model
      end
    end
    
    def add_records model, records
      @template_payloads[model].add_records records

      records.each do |record|
        record.assoc_records(@template_payloads[model].attributes).each do |assoc_model,assoc_records|
          add_records assoc_model, assoc_records
        end
      end
    end

    def add_revision revision
      add_model revision.model
      add_records revision.model, [ revision.record ]
    end

    def to_hash &block
      {
        templates: Hash[
          @template_payloads.map do |model, tp|
            [ 
              model.model_name, tp.to_hash(&block)
            ]
          end
        ]
      }
    end

    private

    class TemplatePayload
      def initialize model, attributes
        @model = model
        @attributes = attributes
        @records = []
      end

      attr_reader :records, :attributes

      def add_records records
        @records.concat records
      end

      def to_hash
        {
          documents: Hash[
            @records.map do |record|
              [
                record.identifier, block_given? ? yield(@model, attributes, record) : record.json_document(attributes)
              ]
            end
          ],
          template: block_given? ? yield(@model, attributes) : @model.json_template
        }
      end
    end
  end
end
