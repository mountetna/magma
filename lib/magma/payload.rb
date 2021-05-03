require 'csv'
require 'json'

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

    def set_predicate_manager(predicate_manager)
      # Because we don't have access to all the records when
      #   generating the headers or rows, we need some context
      #   around what data was requested, specifically
      #   any MatrixAttribute slices. We'll extract that
      #   info from the predicate manager, passed in from
      #   the Retrieval object.
      @predicate_manager = predicate_manager
      @models.values.each do |model|
        model.set_predicate_manager(@predicate_manager)
      end
    end

    private

    class ModelPayload
      def initialize model, attribute_names
        @model = model
        @attribute_names = attribute_names ||
          @model.attributes.reject { |name, attr| attr.primary_key? }.keys
        @records = []
      end

      attr_reader :records, :attribute_names, :predicate_manager

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
        # Need to unmelt any matrix attributes and generate
        #   headers from their columns if `unmelt_matrices` is set.
        [].tap do |headers|
          tsv_attributes.each do |att_name|
            unmelt_matrix?(att_name) ?
              headers.concat(matrix_headers(att_name, predicate_manager)) :
              headers << att_name
          end
        end.join("\t") + "\n"
      end

      def to_tsv
        CSV.generate(col_sep: "\t") do |csv|
          @records.each do |record|
            # Need to unmelt any matrix attributes and expand
            #   their row data into the CSV.
            csv << [].tap do |new_row|
              tsv_attributes.each do |att_name|
                if att_name == :id
                  new_row << record[att_name]
                elsif unmelt_matrix?(att_name)
                  new_row.concat(attribute(att_name).unmelt(record[att_name]))
                else
                  new_row << attribute(att_name).query_to_tsv(record[att_name])
                end
              end
            end
          end
        end
      end

      def set_predicate_manager(predicate_manager)
        @predicate_manager = predicate_manager
      end

      def unmelt_matrix?(att_name)
        predicate_manager&.unmelt_matrices? && is_matrix?(att_name)
      end

      def is_matrix?(att_name)
        attribute(att_name).is_a?(Magma::MatrixAttribute)
      end

      def matrix_headers(att_name, predicate_manager)
        att = attribute(att_name)
        
        column_names = predicate_manager.exists_for?(att) ?
          predicate_manager.operand_for(att) : 
          att.validation_object.options

        column_names.map do |col_name|
          "#{att_name}_#{col_name}"
        end
      end

      private

      def tsv_attributes
        @tsv_attributes ||= @attribute_names.select do |att_name|
          att_name == :id || (attribute(att_name).shown? && !attribute(att_name).is_a?(Magma::TableAttribute))
        end
      end

      def attribute(att_name)
        @model.attributes[att_name]
      end
    end
  end
end
