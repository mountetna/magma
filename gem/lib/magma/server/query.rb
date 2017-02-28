require_relative 'controller'
require_relative '../query/data_table'

class Magma
  class Server
    class Query < Magma::Server::Controller
      def response
        begin
          question = Magma::Question.new @params["query"]
          success answer: question.answer, type: question.type
        rescue ArgumentError => e
          failure 422, e.message
        end
      end
    end
  end
end
