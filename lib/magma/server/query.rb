require_relative "controller"
require_relative "../query/question"
require_relative "../query/query_tsv_writer"

class QueryController < Magma::Controller
  def action
    return failure(401, errors: ["You are unauthorized"]) unless @user && @user.can_view?(@project_name)

    begin
      if @params[:query] == "::predicates"
        return success(Magma::Predicate.to_json, "application/json")
      end
      question = Magma::Question.new(
        @project_name, @params[:query],
        show_disconnected: @params[:show_disconnected],
        restrict: !@user.can_see_restricted?(@project_name),
        user: @user,
        timeout: Magma.instance.config(:query_timeout),
        page: @params[:page],
        order: @params[:order],
        page_size: @params[:page_size],
      )

      return tsv_stream(question) if @params[:format] == "tsv"

      return_data = { answer: question.answer, type: question.type, format: question.format }
      return success(return_data.to_json, "application/json")
    rescue Magma::QuestionError, ArgumentError => e
      return failure(422, errors: [e.message])
    rescue Sequel::DatabaseError => e
      Magma.instance.logger.log_error(e)
      return failure(501, errors: ["Database error."])
    rescue Sequel::Error => e
      return failure(422, errors: [e.message])
    end
  end

  private

  def tsv_stream(question)
    stream = Enumerator.new do |stream|
      Magma::QueryTSVWriter.new(
        question,
        expand_matrices: !!@params[:expand_matrices],
        transpose: !!@params[:transpose],
        columns: @params[:columns]
      ).write_tsv { |lines| stream << lines }
    end

    filename = "#{@project_name}_query_results_#{DateTime.now.strftime("%Y_%m_%d_%H_%M_%S")}.tsv"

    [200, { "Content-Type" => "text/tsv", "Content-Disposition" => "inline; filename=\"#{filename}\"" }, stream]
  end
end
