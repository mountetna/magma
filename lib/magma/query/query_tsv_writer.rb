require_relative "../tsv_writer_base"
require_relative "./query_tsv_utils"

class Magma
  class QueryTSVWriter < Magma::TSVWriterBase
    def initialize(question, opts = {})
      @question = question
      super(opts)
    end

    def write_tsv(&block)
      @transpose ?
        transpose_records(&block) :
        standard_records(&block)
    end

    def standard_records
      yield tsv_header

      yield to_tsv(@question.answer)
    end

    def transpose_records
      # Collect all data, then yield the transposed results
      [].tap do |buffer|
        buffer << tsv_row_to_array(tsv_header)

        buffer.concat(tsv_records_to_array(to_tsv(@question.answer)))
      end.transpose.each do |row|
        yield array_to_tsv_row(row)
      end
    end

    private

    def attr_is_matrix(model_name, attribute_name)
      Magma.instance.get_model(
        @question.model.class.project_name, model_name
      ).attributes[attribute_name.to_sym].is_a?(Magma::MatrixAttribute)
    end

    def path_to_value(search_array, target_value, current_path = [])
      return [] unless search_array
      search_array = [search_array] unless search_array.is_a?(Array)

      direct_index = search_array.find_index(target_value)
      return current_path.concat([direct_index]) unless direct_index.nil?

      search_array.each.with_index do |element, index|
        if element.is_a?(Array)
          temp_path = path_to_value(element, target_value, current_path.concat([index]))
          return temp_path unless temp_path.empty?
        end
      end

      []
    end

    def matrix_attribute_format(model_name, attribute_name)
      require "pry"
      binding.pry
      # path = path_to_value(@question.format, )
    end

    def model_attr_headers
      # "raw" headers that reference only the model + attribute names
      @question.columns
    end

    def tsv_header
      # Start with the raw, internal headers.
      # If the user supplies a :columns option, in
      #   which case, rename according to the :display_label
      model_attr_headers.map do |model_attr_header|
        model_attr_header
      end.join("\t") + "\n"

      # [].tap do |tsv_columns|
      #   @columns.each.with_index do |user_column, index|
      #     next unless user_column[:model_name] && user_column[:attribute_name] && user_column[:display_label]

      #     if (@expand_matrices &&
      #         attr_is_matrix(user_column[:model_name], user_column[:attribute_name]))
      #       matrix_attribute_format(user_column[:model_name], user_column[:attribute_name]).each do |matrix_heading|
      #         tsv_columns << "#{user_column[:display_label]}.#{matrix_heading}"
      #       end
      #     else
      #       tsv_columns << user_column[:display_label]
      #     end
      #   end
      # end
    end

    def to_tsv(records)
      CSV.generate(col_sep: "\t") do |csv|
        records.map do |record|
          csv << model_attr_headers.map do |header|
            require "pry"
            binding.pry
            path = path_to_value(@question.format, header)
            value = record.dig(*path)

            value.is_a?(Array) ? value.map(&:to_s).join(",") : value
          end
        end
      end
    end
  end
end
