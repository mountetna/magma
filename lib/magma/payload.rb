require 'csv'

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

    def add_model model, attribute_names=nil
      return if @models[model]

      @models[model] = ModelPayload.new(model,attribute_names)
    end
    
    def add_records model, records
      @models[model].add_records records
    end

    def add_revision revision
      add_model revision.model

      add_records revision.model, [ revision.record ]
    end

    def to_hash
      response = {}

      if !@models.empty?
        response.update(
          models: Hash[
            @models.map do |model, model_payload|
              [
                model.model_name, model_payload.to_hash
              ]
            end
          ]
        )
      end
      response
    end

    def to_tsv
      # there should only be one model
      @models.first.last.to_tsv
    end

    private

    class ModelPayload
      def initialize model, attribute_names
        @model = model
        @attribute_names = attribute_names
        @records = []
      end

      attr_reader :records, :attribute_names

      def add_records records
        @records.concat records
      end

      def to_hash
        {
          documents: Hash[
            @records.map do |record|
              [
                record[@model.identity], record
              ]
            end
          ],
          template: @model.json_template
        }
      end

      def to_tsv
        attributes = @attribute_names.select do |att_name| 
          @model.attributes[att_name].shown? && !@model.attributes[att_name].is_a?(Magma::TableAttribute)
        end
        attributes.unshift @model.identity unless attributes.include?(@model.identity)

        CSV.generate(col_sep: "\t") do |csv|
          csv << attributes
          @records.each do |record|
            csv << attributes.map do |att_name|
              if att_name == :id
                record[att_name]
              else
                record.txt_for att_name
              end
            end
          end
        end
      end
    end
  end
end
