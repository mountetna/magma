require_relative 'controller'
require_relative '../query/question'

class DataTable
  def initialize query_json
    @name = query_json["name"]

    @row_query = query_json["rows"]
    @column_queries = query_json["columns"]
    @order = query_json["order"]
  end

  def columns
    @columns ||= Hash[
      @column_queries.map do |column_name, column|
        query = Magma::Question.new([ @row_query.first, [ "::identifier", "::in", row_names ], "::all" ] + column)
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

  def col_names
    @column_queries.keys
  end

  def row_names
    @row_names ||= row_question.answer.flatten.uniq
  end

  def to_matrix
  {
    # you need to name your samples
    name: @name,
    matrix: {
      col_names: col_names,
      row_names: row_names,
      rows: rows
    }
  }
  end

  private

  def row_question
    @row_question ||= Magma::Question.new(@row_query + [ "::all", "::identifier" ])
  end

end

class Magma
  class Server
    class Query < Magma::Server::Controller
      def response
        @data_tables = @params["queries"].map do |query_json|
          DataTable.new(query_json)
        end

        [ 200, {}, [ @data_tables.map(&:to_matrix).to_json ] ]
      end
    end
  end
end
