require_relative 'controller'
require_relative '../actions/update_attribute'

class UpdateModelController < Magma::Controller
  def action
    @params[:actions].each do |action_params|
      action_class = "Magma::#{action_params[:action_name].classify}".constantize
      action_class.new(@project_name, action_params).perform
    end

    @payload = Magma::Payload.new

    Magma.instance.get_project(@project_name).models.each do |model_name, model|
      retrieval = Magma::Retrieval.new(model, [], "all")
      @payload.add_model(model, retrieval.attribute_names)
    end

    return success(@payload.to_hash.to_json, 'application/json')
  end
end
