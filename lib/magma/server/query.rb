require_relative 'controller'
require_relative '../query/question.rb'

class QueryController < Magma::Controller
  def action
    return failure(401, errors: [ 'You are unauthorized' ]) unless @user && @user.can_view?(@project_name)
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
