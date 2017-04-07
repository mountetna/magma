require_relative 'question'

class Magma
  class DataTable
    def initialize query_json
      @name = query_json["name"]

      @row_query = query_json["rows"]
      @column_queries = Hash[
        query_json["columns"].map do |column_name, column_query|
          [
            column_name,
            Magma::Question.new(
              [ 
                @row_query.first, 
                [ "::identifier", "::in", row_names ],
                "::all"
              ] + column_query
            )
          ]
        end
      ]
      @order = query_json["order"]
    end

    def to_matrix
    {
      # you need to name your samples
      name: @name,
      matrix: {
        col_names: col_names,
        row_names: ordered(row_names),
        col_types: col_types,
        row_sql: row_question.to_sql,
        sql: @column_queries.values.map(&:to_sql),
        rows: ordered(rows)
      }
    }
    end

    private

    def ordered array
      ord = ordering
      return array unless ord
      ord.map do |i|
        array[i]
      end
    end

    def ordering
      return nil unless @order && columns[@order]
      row_names.map.with_index do |row_name, i|
        [ columns[@order][row_name], i ]
      end.sort_by do |value,i|
        value
      end.map do |value,i|
        i
      end
    end

    def columns
      @columns ||= Hash[
        @column_queries.map do |column_name, query|
          [ column_name, Hash[query.answer] ]
        end
      ]
    end

    def rows
      row_names.map do |row_name|
        columns.map do |column_name, results|
          results[row_name]
        end
      end
    end

    def col_types
      @column_queries.values.map(&:type)
    end

    def col_names
      @column_queries.keys
    end

    def row_names
      @row_names ||= row_question.answer.flatten.uniq
    end

    def row_question
      @row_question ||= Magma::Question.new(@row_query + [ "::all", "::identifier" ])
    end
  end
end
