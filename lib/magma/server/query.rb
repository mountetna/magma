require_relative 'controller'
require_relative '../query/question.rb'

class Magma
  class Server
    class Query < Magma::Server::Controller
      def response
        begin
          question = Magma::Question.new @params[:query]
          success 'application/json', { answer: question.answer, type: question.type }.to_json
        rescue ArgumentError => e
          puts e.backtrace
          failure 422, errors: [ e.message ]
        end
      end
    end
  end
end
