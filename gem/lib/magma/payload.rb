class Magma
  class Payload
    # The payload is ONLY responsible for retrieving
    # information from the model and turning it into JSON. It
    # should not retrieve any data directly (except perhaps by
    # invoking uncomputed model associations). Ideally all of
    # the data is loaded already when passed into the payload.
    def initialize
      @models = {}
    end

    def add_model model, attributes=nil
      return if @models[model]

      @models[model] = ModelPayload.new(model,attributes)
      model.assoc_models(attributes).each do |assoc_model|
        add_model assoc_model
      end
    end
    
    def add_records model, records
      @models[model].add_records records

      records.each do |record|
        record.assoc_records(@models[model].attributes).each do |assoc_model,assoc_records|
          add_records assoc_model, assoc_records
        end
      end
    end

    def add_revision revision
      add_model revision.model
      add_records revision.model, [ revision.record ]
    end

    def to_hash
      # Magma has three interfaces, all of which should return the same type of payload, for
      # ease of consumption
      # There are three TYPES of information magma might return:
      # 1. Template
      # 2. Document
      # 3. Matrix
      #
      # Each of these belong to a project. The expected layout, then:
      # {
      #   projects: {
      #     project_name1: {
      #       models: {
      #         model_name1: {
      #           template: {},
      #           documents: {
      #             record_name1: {},
      #             ...
      #           },
      #           matrices: {
      #             record_name1: {
      #               matrix_name1: {}
      #             }
      #           }
      #         }
      #       }
      #     },
      #     ...
      #   }
      # }
      #
      Hash[
        @models.map do |model, model_payload|
          [
            model.model_name, model_payload.to_hash
          ]
        end
      ]
    end

    private

    class ModelPayload
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
                record.identifier, record.json_document(
                  @attributes
                )
              ]
            end
          ],
          template: @model.json_template
        }
      end
    end
  end
end
