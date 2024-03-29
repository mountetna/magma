require_relative "../tsv_writer_base"
require_relative "./question_format"

class Magma
  class QueryTSVWriter < Magma::TSVWriterBase
    def initialize(project_name, question, opts = {})
      @project_name = project_name
      @question = question

      validate_columns(opts[:user_columns]) if opts[:user_columns]

      @user_columns = opts[:user_columns]

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

    def validate_columns(user_columns)
      raise TSVError.new("user_columns array must be #{model_attr_headers.length} elements long") unless model_attr_headers.length == user_columns.length
    end

    def path_to_value(search_array, target_column, current_path: [], starting_index: nil)
      # Given search_array as a nested set of arrays,
      #   finds the index-path to get to a specific value, starting with
      #   the starting_index if provided.
      # i.e. search_array is [labors::labor#name, [labors::labor#number, labors::monster#name]]
      #   the path to labors::monster#name is [1, 1]
      return [] unless search_array
      search_array = [search_array] unless search_array.is_a?(Array)

      return current_path.concat([starting_index]) if starting_index && search_array[starting_index] == target_column.header

      direct_index = search_array.find_index(target_column.header)
      return current_path.concat([direct_index]) unless direct_index.nil?

      refined_search_array = starting_index.nil? ? search_array : [search_array[starting_index]]

      refined_search_array.each.with_index do |element, index|
        if element.is_a?(Array)
          temp_path = path_to_value(
            element,
            target_column,
            current_path: current_path.concat([starting_index.nil? ? index : starting_index]),
          )
          return temp_path unless temp_path.empty?
        end
      end

      []
    end

    def model_attr_headers
      # "raw" headers that reference only the model + attribute names
      @model_attr_headers ||= @question.columns.map do |col|
        TSVHeader.new(@project_name, col)
      end
    end

    def rename(header, index)
      @user_columns ? @user_columns[index] : header.header
    end

    def matrix_columns(header, index)
      path_to_matrix_attribute = path_to_value(
        @question.format[1],
        header,
        starting_index: index - 1,
      )

      @question.format[1].dig(*(path_to_matrix_attribute.slice(0..-2).concat([1])))
    end

    def expand(header, index)
      renamed_header = rename(header, index)
      matrix_columns(header, index).map do |col|
        "#{renamed_header}.#{col}"
      end
    end

    def tsv_header
      # Start with the raw, internal headers.
      # If the user supplies a :user_columns option, in
      #   which case, rename according to the :display_label
      # Expand matrix headers if necessary
      model_attr_headers.map.with_index do |model_attr_header, index|
        @expand_matrices && model_attr_header.matrix? ?
          expand(model_attr_header, index) :
          rename(model_attr_header, index)
      end.flatten.join("\t") + "\n"
    end

    def to_tsv(records)
      CSV.generate(col_sep: "\t") do |csv|
        records.map do |record|
          csv << [].tap do |row|
            model_attr_headers.each.with_index do |tsv_column, index|
              if index == 0
                # The identifier of the question answer is always located
                #   here. Simplifies the use of starting_index for the
                #   answers, since that index will always be relative to
                #   the data part of the answer tuple.
                row << record.first
                next
              elsif non_nested_single_model_query
                # In this simple use case, we just grab the entire
                #   answer portion
                row << record.last
                next
              else
                path = path_to_value(
                  @question.format[1],
                  tsv_column,
                  starting_index: index - 1,
                )
              end

              raise Magma::TSVError.new("No path to data for #{tsv_column.header}.") if path.empty?

              begin
                value = dig_reduce(record.last, path)
              rescue Magma::MatrixJsonError => e
                Magma.instance.logger.error(record.first)
                Magma.instance.logger.log_error(e)
                value = nil
              end

              if @expand_matrices && tsv_column.matrix?
                row = row.concat(value.nil? ?
                  Array.new(matrix_columns(tsv_column, index - 1).length) { nil } :
                  value)
              else
                row << value
              end
            end
          end
        end
      end
    end

    def non_nested_single_model_query
      # Simple edge case when query is something like
      #   [model, ::all, attribute]
      @question.format.length == 2 &&
      @question.format.last.is_a?(String)
    end

    def dig_reduce(record, path)
      # ["Lernean Hydra", [3, "Susan Doe", [["Shawn Doe", [[87, "Arm"], [88, "Leg"]]], ["Susan Doe", [[86, "Leg"], [85, "Arm"]]]]]]
      # with path [1, 2, 1, 1]
      # should return ["Arm", "Leg", "Leg", "Arm"]
      # because the entry at [1, 2] is an array of branched values, not a path to
      #   an inner value or an explicit answer.
      return nil unless record && path

      queue = path.dup
      value_under_test = record

      while !queue.empty?
        index = queue.shift

        # Sometimes the record won't have data for this attribute
        break if value_under_test.nil?

        entry = value_under_test[index]

        if entry.is_a?(Array) && entry.first.is_a?(Array)
          # Nested data, need to reduce the interior entries to grab
          #   only the requested attribute values.
          inner_path = queue.dup

          return entry.map do |e|
                   dig_reduce(e, inner_path)
                 end.flatten.compact
        elsif entry.is_a?(Magma::MatrixPredicate::MatrixValue)
          return JSON.parse(entry.to_json)
        end

        value_under_test = entry
      end

      # no reduction was required, so just use dig
      record.dig(*path)
    end
  end

  class TSVHeader < Magma::QuestionColumnBase
    attr_reader :header

    def initialize(project_name, header)
      @header = header
      @project_name = project_name
    end

    def matrix?
      is_matrix?(@header)
    end
  end
end
