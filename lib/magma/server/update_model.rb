require_relative 'controller'
require 'magma/actions/model_update_actions'

class UpdateModelController < Magma::Controller
  def action
    model_update_actions = Magma::ModelUpdateActions.build(@project_name, @params[:actions])

    if model_update_actions.perform
      @payload = Magma::Payload.new
      Magma.instance.get_project(@project_name).models.each do |model_name, model|
        retrieval = Magma::Retrieval.new(model, [], "all")
        @payload.add_model(model, retrieval.attribute_names)
      end
      success(@payload.to_hash.to_json, 'application/json')
    else
      failure(422, errors: model_update_actions.errors)
    end
  end
end
