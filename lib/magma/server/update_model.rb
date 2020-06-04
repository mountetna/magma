require_relative 'controller'
require_relative '../actions/update_attribute'

class UpdateModelController < Magma::Controller
  def action
    @params[:actions].each do |action_params|
      action_class = "Magma::#{action_params[:action_name].classify}".constantize
      action_class.new(@project_name, action_params).perform
    end

    success({}, 'application/json')
  end
end
