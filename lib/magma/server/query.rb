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
        @project_name, query_array,
        show_disconnected: @params[:show_disconnected],
        restrict: !@user.can_see_restricted?(@project_name),
        user: @user,
        timeout: Magma.instance.config(:query_timeout),
        page: @params[:page],
        order: @params[:order],
        page_size: @params[:page_size],
      )

      case format
      when 'tsv'
        return tsv_payload(question)
      else
        return json_payload(question)
      end
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

  def query_array
    # forms (to download a TSV, for example), do not handle
    #   nested arrays elegantly. So we also accept a JSON-stringified
    #   version of a query
    @params[:query].is_a?(Array) ? @params[:query] : JSON.parse(@params[:query])
  end

  def format
    @params[:format]
  end

  def json_payload(question)
    return_data = { answer: question.answer, type: question.type, format: question.format }
    return success(return_data.to_json, "application/json")
  end

  def tsv_payload(question)
    stream = Enumerator.new do |stream|
      Magma::QueryTSVWriter.new(
        question,
        expand_matrices: !!@params[:expand_matrices],
        transpose: !!@params[:transpose],
        user_columns: user_columns_array,
      ).write_tsv { |lines| stream << lines }
    end

    filename = "#{@project_name}_query_results_#{DateTime.now.strftime("%Y_%m_%d_%H_%M_%S")}.tsv"

    [200, { "Content-Type" => "text/tsv", "Content-Disposition" => "inline; filename=\"#{filename}\"" }, stream]
  end

  def user_columns_array
    # forms (to download a TSV, for example), do not handle
    #   nested arrays elegantly. So we also accept a JSON-stringified
    #   version of the user_columns
    return nil unless @params[:user_columns]

    @params[:user_columns].is_a?(Array) ? @params[:user_columns] : JSON.parse(@params[:user_columns])
  end
end
