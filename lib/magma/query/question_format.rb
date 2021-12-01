class Magma
  class QuestionFormatPaths
    def initialize(project_name, data)
      data = [data] unless data.is_a?(Array)

      @paths = data.map do |datum|
        Magma::QuestionFormatPath.new(project_name, datum)
      end
    end

    def leaves
      @paths.map(&:leaves).flatten
    end
  end

  class QuestionColumnBase
    private

    def is_matrix?(model_attr)
      Magma.instance.get_model(
        @project_name, model_name(model_attr)
      ).attributes[attribute_name(model_attr).to_sym].is_a?(Magma::MatrixAttribute)
    end

    def model_name(model_attr)
      model_attr.split("::").last.split("#").first
    end

    def attribute_name(model_attr)
      model_attr.split("#").last.split(".").first
    end
  end

  class QuestionFormatPath < QuestionColumnBase
    def initialize(project_name, data)
      @project_name = project_name
      @data = data
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
              result << first_part
            else
              result = result.concat(Magma::QuestionFormatPath.new(
                @project_name, last_part
              ).leaves)
            end
          end
        else
          result << @data
        end
      end
    end
  end

  class QuestionFormat
    attr_reader :model_attr

    def initialize(project_name, format_array)
      @project_name = project_name

      raise "Invalid format" unless Magma::QuestionFormat.is_raw_format_array?(format_array)

      @model_attr = format_array.first
      @paths = Magma::QuestionFormatPaths.new(
        @project_name, format_array.last
      )
    end

    def leaves
      [].tap do |result|
        result << model_attr
        result = result.concat(@paths.leaves)
      end
    end

    def self.is_raw_format_array?(element)
      # In query format, we expect to have
      #   an array in the form of [string, array] or
      #   [string, string]
      element.is_a?(Array) &&
      element.length == 2 &&
      (element.last.is_a?(Array) || element.last.is_a?(String)) &&
      element.first.is_a?(String)
    end
  end
end
