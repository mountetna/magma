require 'set'
require 'json'

class Magma
  class MatrixAttribute < Attribute
    def database_type
      :json
    end

    def entry(value, loader)
      [ column_name, value.to_json ]
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value, &block)
        # nil is a valid value
        return if value.nil?

        # it must be an array of numbers
        yield "Matrix value is not an array of numbers" unless value.is_a?(Array) && value.all?{|v| v.is_a?(Numeric)}
        yield "Improper matrix row size" unless validation_object.options.size == value.size
      end
    end

    def revision_to_loader(record_name, new_value)
      cached_rows.delete(record_name.to_s)
      cached_rows_json.delete(record_name.to_s)

      [ name, new_value ]
    end

    def revision_to_payload(record_name, new_value, loader)
      [ name, new_value ]
    end

    def unmelt(matrix_value)
      # Provide an embedded data frame inside of the TSV
      #   that includes the selected columns names + values.

      # matrix_value.to_json is actually a JSON string.
      JSON.parse(matrix_value.to_json)
    end

    def reset_cache
      @cached_rows_json = nil
      @cached_rows = nil
    end

    def cache_rows(identifiers)
      required_identifiers = identifiers - cached_rows.keys

      return if required_identifiers.empty?

      rows = @magma_model.
        where(@magma_model.identity.column_name.to_sym => required_identifiers.to_a).
        select_map([@magma_model.identity.column_name.to_sym, column_name.to_sym]).
        to_h

      cached_rows.update(rows)
    end

    def matrix_row_json(identifier, column_names)
      # since we want to retrieve rows in a single batch, we expect the row to
      # have been cached already by #cache_rows
      raise unless cached_rows.has_key?(identifier)

      if column_names
        indexes = column_indexes(column_names)
        cached_rows[identifier] ? cached_rows[identifier].values_at(
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

    def cached_rows_json
      @cached_rows_json ||= {}
    end

    def cached_row_json(identifier)
      cached_rows_json[ identifier ] ||= cached_rows[ identifier ] ?  cached_rows[ identifier ].to_json : null_row_json
    end

    def null_row_json
      @null_row_json ||= validation_object.options.map{nil}.to_json
    end

    def column_indexes(names)
      @column_indexes ||= validation_object.options.map.with_index{|name,i| [ name, i ]}.to_h

      @column_indexes.values_at(*names)
    end
  end
end
