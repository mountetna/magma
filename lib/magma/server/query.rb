require_relative 'controller'
require_relative '../query/question.rb'

class QueryController < Magma::Controller
  def action
    return failure(401, errors: [ 'You are unauthorized' ]) unless @user && @user.can_view?(@project_name)

    begin
      if @params[:query] == '::predicates'
        return success(Magma::Predicate.to_json, 'application/json')
      end
      question = Magma::Question.new(@project_name, @params[:query],
                                     restrict: !@user.can_see_restricted?(@project_name),
                                     timeout: Magma.instance.config(:query_timeout))
      return_data = {answer: question.answer, type: question.type, format: question.format}
      return success(return_data.to_json, 'application/json')
    rescue Magma::QuestionError => e
      return failure(422, errors: [ e.message ])
    rescue Sequel::DatabaseError => e
      Magma.instance.logger.log_error(e)
      return failure(501, errors: 'Database error.')
    end
  end
end
