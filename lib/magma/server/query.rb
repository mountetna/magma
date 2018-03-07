require_relative 'controller'
require_relative '../query/question.rb'

class QueryController < Magma::Controller
  def action
    return failure(401, errors: [ 'You are unauthorized' ]) unless @user && @user.can_view?(@project_name)
    begin
      return success(Magma::Predicate.to_json, 'application/json') if @params[:query] == '::predicates'
      question = Magma::Question.new(@project_name, @params[:query],
                                     :timeout => Magma.instance.config(:query_timeout))
      return_data = {answer: question.answer, type: question.type}
      return success(return_data.to_json, 'application/json')
    rescue ArgumentError => e
      puts e.backtrace
      return failure(422, errors: [ e.message ])
    rescue Sequel::DatabaseError => e
      puts e.backtrace
      return failure(501, errors: [ e.message ])
    end
  end
end
