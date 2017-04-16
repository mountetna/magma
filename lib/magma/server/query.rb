require_relative 'controller'
require_relative '../query/data_table'


class Magma
  class Server
    class Query < Magma::Server::Controller
      def response
        begin
          question = Magma::Question.new @params["query"]
          success 'application/json', { answer: question.answer, type: question.type }.to_json
        rescue ArgumentError => e
          puts e.backtrace
          failure 422, e.message
        end
      end
    end
  end
end
