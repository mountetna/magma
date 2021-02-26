require 'csv'

class Magma
  class Payload
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

    def add_count model, count
      @models[model].add_count count
    end

    def reset model
      @models[model].reset
    end

    def to_hash(hide_templates=nil)
      response = {}

      if !@models.empty?
        response.update(
          models: Hash[
            @models.map do |model, model_payload|
              [
                model.model_name, model_payload.to_hash(hide_templates)
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

    def tsv_header
      @models.first.last.tsv_header
    end

    private

    class ModelPayload
      def initialize model, attribute_names
        @model = model
        @attribute_names = attribute_names ||
          @model.attributes.reject { |name, attr| attr.primary_key? }.keys
        @records = []
      end

      attr_reader :records, :attribute_names

      def add_records records
        @records.concat records
      end

      def add_count count
        @count = count
      end

      def reset
        @records = []
      end

      def to_hash(hide_templates=nil)
        {
          documents: Hash[
            @records.map do |record|
              [
                record[@model.identity.attribute_name.to_sym], json_document(record)
              ]
            end
          ],
          template: hide_templates ? nil : @model.json_template,
          count: @count
        }.compact
      end

      def json_document record
        # A JSON version of this record (actually a hash). Each attribute
        # reports in its own fashion
        Hash[
          @attribute_names.map do |attribute_name|
            record.has_key?(attribute_name) ?  [
              attribute_name, record[attribute_name]
            ] : nil
          end.compact
        ]
      end

      def tsv_header
        tsv_attributes.join("\t") + "\n"
      end

      def to_tsv
        CSV.generate(col_sep: "\t") do |csv|
          @records.each do |record|
            csv << tsv_attributes.map do |att_name|
              if att_name == :id
                record[att_name]
              else
                @model.attributes[att_name].query_to_tsv(record[att_name])
              end
            end
          end
        end
      end

      private

      def tsv_attributes
        @tsv_attributes ||= @attribute_names.select do |att_name|
          att_name == :id || (@model.attributes[att_name].shown? && !@model.attributes[att_name].is_a?(Magma::TableAttribute))
        end
      end
    end
  end
end
