class Magma
  class ValidationObject
    def self.build(options = {})
      type = options ? options.fetch(:type) : "Null"
      "Magma::#{type}ValidationObject".constantize.new(options)
    end

    def initialize(options = {})
      @options = options
      type = options.fetch(:type).constantize
      args = object_args(options)
      @object = type.new(*args)
    end

    def validate(value)
    end

    def error_message(name, value, hint)
    end

    def options
    end

    def match
    end

    def to_json(options = nil)
      @options.to_json
    end

    private

    def object_args(options)
      [options.fetch(:value)]
    end
  end

  class NullValidationObject < ValidationObject
    def initialize(options = {})
      @object = nil
    end

    def validate(value)
      true
    end
  end

  class ArrayValidationObject < ValidationObject
    def validate(value)
      @object.map(&:to_s).include?(value)
    end

    def error_message(name, value, hint)
      "On #{name}, '#{value}' should be one of #{@object.join(", ")}."
    end

    def options
      @object
    end
  end

  class RangeValidationObject < ValidationObject
    def validate(value)
      @object.include?(value)
    end

    def error_message(name, value, hint)
      end_expression = @object.exclude_end? ? "less than" : "less than or equal to"

      "On #{name}, #{value} should be greater than or equal to #{@object.begin} and #{end_expression} #{@object.end}."
    end

    private

    def object_args(options)
      options.values_at(:begin, :end, :exclude_end)
    end
  end

  class RegexpValidationObject < ValidationObject
    def validate(value)
      value.is_a?(String) && @object.match?(value)
    end

    def error_message(name, value, hint)
      if hint
        "On #{name}, '#{value}' should be like '#{hint}'."
      else
        "On #{name}, '#{value}' is improperly formatted."
      end
    end

    def match
      @object.source
    end

    private

    def object_args(options)
      if options[:value].respond_to?(:call)
        [options[:value].call]
      else
        super
      end
    end
  end
end
