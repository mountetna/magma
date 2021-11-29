class Magma
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
      query_format = convert(data_source, expand_matrices)

      # We may be able to re-use this in the path-finding for
      #   extracting answer values, but not clear yet.
      [].tap do |result|
        result << query_format.model_attr
        result = result.concat(query_format.leaves)
      end
    end

    private

    def convert(raw_data, expand_matrices)
      raise "Not valid format" unless Magma::QueryFormat.is_raw_format_tuple?(raw_data)

      Magma::QueryFormat.new(
        @project_name,
        raw_data,
        expand_matrices
      )
    end
  end

  class QueryFormatPaths
    def initialize(project_name, data, expand_matrices)
      @paths = data.map do |datum|
        Magma::QueryFormatPath.new(project_name, datum, expand_matrices)
      end
    end

    def leaves
      @paths.map(&:leaves).flatten
    end
  end

  class QueryFormatPath
    def initialize(project_name, data, expand_matrices)
      @project_name = project_name
      @data = data
      @expand_matrices = expand_matrices
    end

    def leaves
      [].tap do |result|
        if @data.is_a?(Array)
          first_part = @data.first
          last_part = @data.last
          if last_part.is_a?(String)
            result << last_part
          elsif last_part.is_a?(Array)
            if is_matrix?(first_part)
              if @expand_matrices
                result = result.concat(last_part.map do |matrix_column|
                  "#{first_part}.#{matrix_column}"
                end)
              else
                result << first_part
              end
            else
              result = result.concat(Magma::QueryFormatPath.new(
                @project_name, last_part, @expand_matrices
              ).leaves)
            end
          end
        else
          result << @data
        end
      end
    end

    private

    def model_name(model_attr)
      model_attr.split("::").last.split("#").first
    end

    def attribute_name(model_attr)
      model_attr.split("#").last
    end

    def is_matrix?(model_attr)
      Magma.instance.get_model(
        @project_name, model_name(model_attr)
      ).attributes[attribute_name(model_attr).to_sym].is_a?(Magma::MatrixAttribute)
    end
  end

  class QueryFormat
    attr_reader :model_attr

    def initialize(project_name, tuple, expand_matrices)
      @project_name = project_name
      @expand_matrices = expand_matrices

      @model_attr = tuple.first
      @paths = Magma::QueryFormatPaths.new(
        @project_name, tuple.last, @expand_matrices
      )
    end

    def leaves
      @paths.leaves
    end

    def self.is_raw_format_tuple?(element)
      # In query format, we expect to have
      #   a tuple in the form of [string, array]
      element.is_a?(Array) &&
      element.length == 2 &&
      element.last.is_a?(Array) &&
      element.first.is_a?(String)
    end
  end
end
