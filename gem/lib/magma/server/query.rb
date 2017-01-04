require_relative 'controller'
require_relative '../query/question'

class DataTable
  def initialize query_json
    @name = query_json["name"]

    @row_query = query_json["rows"]
    @column_queries = query_json["columns"]
    @order = query_json["order"]
  end

  def rows
    row_question = Magma::Question.new(@row_query + [ "::all", "::identifier" ])
    row_ids = row_question.answer
    Hash[
      @column_queries.map do |column_name, column|
        query = Magma::Question.new([ @row_query.first, [ "::identifier", "::in", row_ids ], "::all" ] + column)
        [ column_name, query.to_sql ]
      end
    ]
  end

  def row_names
    predicates = @row_query + [ "::all", "::identifier" ]
    model = ModelListPredicate.new(*predicates)
    []
  end

  def to_matrix
  {
    # you need to name your samples
    name: @name,
    matrix: {
      col_names: [],
      row_names: [],
      rows: rows
    }
  }
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
