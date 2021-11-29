class Magma
  class QueryTSVUtil
    def initialize(project_name:, expand_matrices: false)
      @expand_matrices = expand_matrices
      @project_name = project_name
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

    def is_nested_tuple?(element)
      # In query format / answer, we expect to have
      #   "final" tuples in the form of [string, array]
      element.is_a?(Array) &&
        element.length == 2 &&
        element.last.is_a?(Array) &&
        element.first.is_a?(String)
    end

    def reduce_leaves(data_source, reduce_depth = 1, current_depth = 0)
      # Given the @question.format and @question.answer,
      #   typically (except for Matrices with ::slice?)
      #   what the user queried for is in the leaf
      #   values of a set of nested arrays.
      # So here we extract only the leaf values.
      # We also specify a reduce_depth, where we start
      #   reducing the leaves. Below that depth,
      #   we'll just return nested arrays of values.

      # Ugly and needs refactoring...
      [].tap do |result|
        data_source.each do |element|
          if (current_depth < reduce_depth && !element.is_a?(Array))
            result << element
          elsif is_nested_tuple?(element)
            inner_result = []

            inner_result << element.first if current_depth < reduce_depth
            inner_result = inner_result.concat(reduce_leaves(element.last, reduce_depth, current_depth + 1))

            result << inner_result
          elsif element.is_a?(Array)
            if element.all? { |e| is_nested_tuple?(e) }
              inner_result = []
              element.each do |child_element|
                inner_result = inner_result.concat(reduce_leaves(child_element, reduce_depth, current_depth + 1))
              end

              if current_depth >= reduce_depth
                result << inner_result.flatten
              else
                result = result.concat(inner_result)
              end
            else
              if element.all? { |e| e.is_a?(Array) }
                leaves = element.map(&:last)
                if current_depth >= reduce_depth
                  result << leaves
                else
                  result = result.concat(leaves)
                end
              else
                result << element.last
              end
            end
          end
        end
      end
    end
  end

  class QueryFormatReducer
    # Nested arrays of QueryFormatTuples
    def initialize(project_name)
      @project_name = project_name
    end

    def reduce_leaves(data_source:, expand_matrices: false)
      # Given the @question.format,
      #   what the user queried for is in the leaf
      #   values of a set of nested arrays.
      # So here we extract only the leaf values.
      data_source = convert(data_source, expand_matrices)

      # We may be able to re-use this in the path-finding for
      #   extracting answer values, but not clear yet.
      [].tap do |result|
        if data_source.is_a?(Magma::QueryFormatTuple)
          result << data_source.model_attr
          result = result.concat(data_source.leaves)
        elsif data_source.is_a?(Magma::QueryFormatTupleArray) # Not used for format?
          data_source.each do |tuple|
            inner_result = []
            inner_result << tuple.model_attr
            inner_result = inner_result.concat(tuple.leaves)

            result = result.concat(inner_result)
          end
        end
      end
    end

    private

    def convert(raw_data, expand_matrices)
      if Magma::QueryFormatTuple.is_raw_format_tuple?(raw_data)
        Magma::QueryFormatTuple.new(
          @project_name,
          raw_data,
          expand_matrices
        )
      elsif Magma::QueryFormatTupleArray.is_raw_format_tuple_array?(raw_data)
        Magma::QueryFormatTupleArray.new(
          @project_name,
          raw_data,
          expand_matrices
        )
      else
        raw_data
      end
    end
  end

  class QueryFormatTupleArray
    def initialize(project_name, data, expand_matrices)
      @tuples = data.map do |datum|
        Magma::QueryFormatTuple.new(
          project_name, datum, expand_matrices
        )
      end
    end

    def leaves
      @tuples.map do |tuple|
        tuple.leaves
      end.flatten
    end

    def each(&block)
      yield @tuples.each(&block)
    end

    def self.is_raw_format_tuple_array?(elements)
      elements.is_a?(Array) &&
      elements.all? { |e| Magma::QueryFormatTuple.is_raw_format_tuple?(e) }
    end
  end

  class QueryFormatTuple
    def initialize(project_name, tuple, expand_matrices)
      raise "Invalid tuple" unless Magma::QueryFormatTuple.is_raw_format_tuple?(tuple)

      @project_name = project_name
      @expand_matrices = expand_matrices

      if Magma::QueryFormatTupleArray.is_raw_format_tuple_array?(tuple.last)
        @tuple = [
          tuple.first,
          Magma::QueryFormatTupleArray.new(project_name, tuple.last, expand_matrices),
        ]
      elsif Magma::QueryFormatTuple.is_raw_format_tuple?(tuple.last)
        @tuple = [
          tuple.first,
          Magma::QueryFormatTuple.new(project_name, tuple.last, expand_matrices),
        ]
      else
        @tuple = tuple
      end
    end

    def model_attr
      @tuple.first
    end

    def model_name
      model_attr.split("::").last.split("#").first
    end

    def attribute_name
      model_attr.split("#").last
    end

    def model
      Magma.instance.get_model(@project_name, model_name)
    end

    def attribute
      model.attributes[attribute_name.to_sym]
    end

    def leaves
      if @tuple.last.is_a?(Magma::QueryFormatTupleArray) || @tuple.last.is_a?(Magma::QueryFormatTuple)
        @tuple.last.leaves
      elsif attribute.is_a?(Magma::MatrixAttribute) && @expand_matrices
        @tuple.last.map do |matrix_column|
          "#{@tuple.first}.#{matrix_column}"
        end
      elsif attribute.is_a?(Magma::MatrixAttribute) && !@expand_matrices
        [@tuple.first]
      elsif @tuple.last.is_a?(Array)
        test_element = @tuple.last.first

        if (test_element.is_a?(Array))
          @tuple.last.map(&:last)
        else
          @tuple.last.last
        end
      else
        @tuple.last
      end
    end

    def is_matrix?
      Magma.instance.get_model(
        @project_name, model_name
      ).attributes[attribute_name.to_sym].is_a?(Magma::MatrixAttribute)
    end

    def self.is_raw_format_tuple?(element)
      # In query format / answer, we expect to have
      #   "final" tuples in the form of [string, array]
      element.is_a?(Array) &&
      element.length == 2 &&
      element.last.is_a?(Array) &&
      element.first.is_a?(String)
    end
  end

  # def matrix_attribute_format(model_name, attribute_name)
  #   require "pry"
  #   binding.pry
  #   # path = path_to_value(@question.format, )
  # end

  # def model_attr_headers
  #   # "raw" headers that reference only the model + attribute names
  #   @model_attr_headers ||= begin
  #       headers = [@question.format.first]

  #       answer_format = @question.format.last

  #       if answer_format.is_a?(Array)
  #         headers = headers.concat(answer_format.map do |header|
  #           header.is_a?(Array) ?
  #             header.flatten.last : # probably won't work for matrices?
  #             header
  #         end)
  #       else
  #         headers << answer_format
  #       end

  #       headers
  #     end
  # end

  # def tsv_header
  #   # Start with the raw, internal headers.
  #   # If the user supplies a :columns param, in
  #   #   which case, rename according to the :display_label
  #   model_attr_headers.map do |model_attr_header|
  #     model_attr_header
  #   end.join("\t") + "\n"

  #   # [].tap do |tsv_columns|
  #   #   @columns.each.with_index do |user_column, index|
  #   #     next unless user_column[:model_name] && user_column[:attribute_name] && user_column[:display_label]

  #   #     if (@expand_matrices &&
  #   #         attr_is_matrix(user_column[:model_name], user_column[:attribute_name]))
  #   #       matrix_attribute_format(user_column[:model_name], user_column[:attribute_name]).each do |matrix_heading|
  #   #         tsv_columns << "#{user_column[:display_label]}.#{matrix_heading}"
  #   #       end
  #   #     else
  #   #       tsv_columns << user_column[:display_label]
  #   #     end
  #   #   end
  #   # end
  # end

  # def to_tsv(records)
  #   CSV.generate(col_sep: "\t") do |csv|
  #     records.map do |record|
  #       csv << model_attr_headers.map do |header|
  #         require "pry"
  #         binding.pry
  #         path = path_to_value(@question.format, header)
  #         record.dig(*path)
  #       end
  #     end
  #   end
  # end
end
