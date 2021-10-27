require_relative 'controller'
require_relative '../query/question.rb'

class QueryController < Magma::Controller
  def action
    return failure(401, errors: [ 'You are unauthorized' ]) unless @user && @user.can_view?(@project_name)

    begin
      if @params[:query] == '::predicates'
        return success(Magma::Predicate.to_json, 'application/json')
      end
      question = Magma::Question.new(
        @project_name, @params[:query],
        show_disconnected: @params[:show_disconnected],
        restrict: !@user.can_see_restricted?(@project_name),
        user: @user,
        timeout: Magma.instance.config(:query_timeout),
        page: @params[:page],
        order: @params[:order],
        page_size: @params[:page_size]
      )
      return_data = {answer: question.answer, type: question.type, format: question.format}
      return success(return_data.to_json, 'application/json')
    rescue Magma::QuestionError, ArgumentError, Sequel::Error => e
      return failure(422, errors: [ e.message ])
    rescue Sequel::DatabaseError => e
      Magma.instance.logger.log_error(e)
      return failure(501, errors: ['Database error.'])
    end
  end
end
