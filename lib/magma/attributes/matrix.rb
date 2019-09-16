require 'set'

class Magma
  class MatrixAttribute < Attribute
    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value, &block)
        return if value.nil? || value.empty?
        return if value.is_a?(Array) && value.all?{|v| v.is_a?(Numeric)}
        yield "#{value.to_json} is not an array of numbers"
      end
    end

    def update(record, new_value)
      record.set({@name=> new_value})

      @cached_rows.delete(record.identifier)
      @cached_row_json.delete(record.identifier)

      return new_value
    end

    def cache_rows(identifiers)

      required_identifiers = identifiers - cached_rows.keys

      return if required_identifiers.empty?

      @cached_rows.update(
        @model.where( @model.identity => required_identifiers.to_a ).select_map( [ @model.identity, @name ] ).to_h
      )
    end

    def matrix_row_json(identifier, column_names)
      raise unless @cached_rows.has_key?(identifier)
      if column_names
        indexes = column_indexes(column_names)
        @cached_rows[identifier] ? @cached_rows[identifier].values_at(
          *indexes
        ).to_json : indexes.map{nil}.to_json
      else
        cached_row_json(identifier)
      end
    end

    private

    def cached_rows
      @cached_rows ||= {}
    end

    def cached_row_json(identifier)
      @cached_row_json ||= {}

      @cached_row_json[ identifier ] ||= @cached_rows[ identifier ] ?
        @cached_rows[ identifier ].to_json : null_row_json
    end

    def null_row_json
      @null_row_json ||= @match.map{nil}.to_json
    end

    def column_indexes(names)
      @column_indexes ||= @match.map.with_index{|name,i| [ name, i ]}.to_h

      @column_indexes.values_at(*names)
    end
  end
end
