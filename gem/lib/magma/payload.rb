class Magma
  class Payload
    def initialize model, records
      @model = model
      @records = records
      @template_payloads = {}

      acquire_data
    end

    attr_reader :template_payloads

    private

    class TemplatePayload
      def initialize model
        @model = model
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

    def add_model model
      @template_payloads[model] ||= TemplatePayload.new(model)
    end

    def add_records model, records
      @template_payloads[model].add_records records

      records.each do |record|
        record.assoc_records.each do |model,records|
          add_records model, records
        end
      end
    end

    def acquire_data
      @model.assoc_models.each do |assoc_model|
        add_model assoc_model
      end

      # at this point, I have:
      # template_payloads for Sample, Population, Mfi
      # I need: records for sample, populations, mfi
      add_records @model, @records
    end
  end
end
