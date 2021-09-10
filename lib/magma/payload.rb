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

    def set_output_format(output_format)
      # Because we don't have access to all the records when
      #   generating the headers or rows, we need some context
      #   around what data was requested, specifically
      #   any MatrixAttribute slices. We can extract
      #   that from the output format.
      @models.values.each do |model|
        model.set_output_format(output_format)
      end
    end

    def set_options(opts)
      @models.values.each do |model|
        model.set_options(opts)
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

      attr_reader :records, :attribute_names, :opts

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
        # Need to expand any matrix attributes and generate
        #   headers from their columns if `expand_matrices` is set.
        [].tap do |headers|
          tsv_attributes.each do |att_name|
            expand_matrix?(att_name) ?
              headers.concat(matrix_headers(att_name)) :
              headers << att_name
          end
        end.join("\t") + "\n"
      end

      def to_tsv
        CSV.generate(col_sep: "\t") do |csv|
          @records.each do |record|
            # Need to expand any matrix attributes and expand
            #   their row data into the CSV.
            csv << [].tap do |new_row|
              tsv_attributes.each do |att_name|
                if att_name == :id
                  new_row << record[att_name]
                elsif expand_matrix?(att_name)
                  new_row.concat(attribute(att_name).expand(record[att_name]))
                else
                  new_row << attribute(att_name).query_to_tsv(record[att_name])
                end
              end
            end
          end
        end
      end

      def set_output_format(output_format)
        @output_format = output_format
      end

      def set_options(opts)
        @opts = opts
      end

      private

      def tsv_attributes
        @tsv_attributes ||= @attribute_names.select do |att_name|
          (!is_self_table? && att_name == :id) || (attribute(att_name).shown? && !attribute(att_name).is_a?(Magma::TableAttribute))
        end
      end

      def is_self_table?
        return false unless (parent_model = @model.parent_model)
        !!parent_model.attributes.values.find { |a| a.is_a?(Magma::TableAttribute) && a.link_model == @model }
      end

      def attribute(att_name)
        @model.attributes[att_name]
      end

      def expand_matrix?(att_name)
        !!opts[:expand_matrices] && is_matrix?(att_name)
      end

      def is_matrix?(att_name)
        attribute(att_name).is_a?(Magma::MatrixAttribute)
      end

      def matrix_headers(att_name)
        # Output format is a tuple, with index 1
        #   being an Array of output formats.
        # Check each item in output_format[1]. If it
        #   is an Array, check the first item. It
        #   is a matrix if it matches the
        #   att_format_key. The selected options
        #   will appear in the last item of that format tuple.
        # This method assumes that the matrix attribute
        #   will be in the output format, or throws
        #   an exception (because the code should have
        #   never reached this point).
        # Use @model.project_name and @model.model_name to force
        #   the names into snake_case, to match output format.
        att_format_key = "#{@model.project_name}::#{@model.model_name}##{att_name}"

        @output_format.last.each do |output|
          next unless output.is_a?(Array) && output.first == att_format_key
          
          return output.last.map do |col_name|
            "#{att_name}.#{col_name}"
          end
        end

        raise "Matrix attribute #{att_name} not found in output format."
      end
    end
  end
end
