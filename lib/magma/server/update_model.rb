require_relative 'controller'
require_relative '../actions/update_attribute'

class UpdateModelController < Magma::Controller
  def action
    actions = @params[:actions].map do |action_params|
      action_class = "Magma::#{action_params[:action_name].classify}Action".constantize
      action_class.new(@project_name, action_params)
    end

    if actions.all?(&:validate) && actions.all?(&:perform)
      @payload = Magma::Payload.new

      Magma.instance.get_project(@project_name).models.each do |model_name, model|
        retrieval = Magma::Retrieval.new(model, [], "all")
        @payload.add_model(model, retrieval.attribute_names)
      end

      success(@payload.to_hash.to_json, 'application/json')
    else
      failure(422, errors: actions.flat_map(&:errors))
    end
  end
end