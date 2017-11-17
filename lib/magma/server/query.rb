require_relative 'controller'
require_relative '../query/question.rb'

class Magma
  class QueryController < Magma::Controller
    def response
      begin
        return success('application/json', Magma::Predicate.to_json) if @params[:query] == '::predicates'
        question = Magma::Question.new(@project_name, @params[:query])
        return_data = {answer: question.answer, type: question.type}
        success('application/json', return_data.to_json)
      rescue ArgumentError => e
        puts e.backtrace
        failure 422, errors: [ e.message ]
      end
    end
  end
end
