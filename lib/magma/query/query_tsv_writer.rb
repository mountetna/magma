require_relative "../tsv_writer_base"
require_relative "./query_tsv_utils"

class Magma
  class QueryTSVWriter < Magma::TSVWriterBase
    def initialize(question, opts = {})
      @question = question
      @question.set_expand_matrices(opts[:expand_matrices]) if opts[:expand_matrices]
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

    def project_name
      @question.model.project_name
    end

    def attr_is_matrix(model_name, attribute_name)
      Magma.instance.get_model(
        project_name, model_name
      ).attributes[attribute_name.to_sym].is_a?(Magma::MatrixAttribute)
    end

    def path_to_value(search_array, target_column, current_path = [])
      return [] unless search_array
      search_array = [search_array] unless search_array.is_a?(Array)

      direct_index = search_array.find_index(target_column.header)
      return current_path.concat([direct_index]) unless direct_index.nil?

      search_array.each.with_index do |element, index|
        if element.is_a?(Array)
          temp_path = path_to_value(element, target_column, current_path.concat([index]))
          return temp_path unless temp_path.empty?
        end
      end

      []
    end

    def path_to_matrix_value(search_array, matrix_heading)
      attribute_path = path_to_value(search_array, TSVHeader.new(
        project_name,
        matrix_heading.model_attr_col
      ))

      if @expand_matrices
        matrix_columns_path = attribute_path.slice(0..-2).concat([1])

        matrix_columns = search_array.dig(*matrix_columns_path)

        attribute_path.slice(0..-2).concat([matrix_columns.find_index(matrix_heading.matrix_column_name)])
      else
        # We don't need the extra 0 introduced due to the
        #   nested matrix array
        attribute_path.slice(0..-2)
      end
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
            tsv_column = TSVHeader.new(project_name, header)

            if tsv_column.matrix_col?
              path = path_to_matrix_value(@question.format, tsv_column)
            else
              path = path_to_value(@question.format, tsv_column)
            end

            raise Magma::TSVError.new("No path to data for #{tsv_column.header}.") if path.empty?

            value = dig_flat(record, path)

            value.map(&:to_s).join(",")
          end
        end
      end
    end

    def dig_flat(record, path)
      # ["Lernean Hydra", [3, "Susan Doe", [["Shawn Doe", [[87, "Arm"], [88, "Leg"]]], ["Susan Doe", [[86, "Leg"], [85, "Arm"]]]]]]
      # with path [1, 2, 1, 1]
      # should return ["Arm", "Leg", "Leg", "Arm"]
      # because the entry at [1, 2] is an array of branched values, not a path to
      #   an inner value or an explicit answer?
      # Blah, and what do you do about matrices?
      queue = path.dup
      flattened_values = []
      value_under_test = record

      while !queue.empty?
        index = queue.shift
        entry = value_under_test[index]
        if entry.is_a?(Array) && entry.first.is_a?(Array)
          # branched record, need to reduce the interior entries
          inner_path = queue.dup

          entry.each do |e|
            flattened_values = flattened_values.concat(dig_flat(e, inner_path))
          end

          # We leave the loop because we've had to reduce
          break
        elsif entry.is_a?(Magma::MatrixPredicate::MatrixValue) && @expand_matrices
          # if we expand the matrix, need to unpack the MatrixValue
          unpacked_matrix = JSON.parse(entry.to_json)

          matrix_index = queue.shift

          flattened_values = [unpacked_matrix[matrix_index]]
          break
        elsif entry.is_a?(Magma::MatrixPredicate::MatrixValue)
          flattened_values = JSON.parse(entry.to_json)
          break
        end

        value_under_test = entry
      end

      # no reduction was required, so just use dig
      if queue.empty? && flattened_values.empty?
        flattened_values = [record.dig(*path)]
      end

      flattened_values
    end
  end

  class TSVHeader < Magma::QuestionColumnBase
    attr_reader :header

    def initialize(project_name, header)
      @header = header
      @project_name = project_name
    end

    def matrix_col?
      is_matrix?(@header)
    end

    def model_attr_col
      @header.split(".").first
    end

    def matrix_column_name
      raise "Unavailable" unless matrix_col?

      @header.split(".").last
    end
  end
end
