require_relative 'base_action'
require_relative 'update_attribute'
require_relative 'add_attribute'

class Magma
  class ModelUpdateActions
    def self.build(project_name, actions_list)
      new(project_name, actions_list)
    end

    def perform
      valid? && @actions.all?(&:perform)
    end

    def errors
      @errors + @actions.flat_map(&:errors)
    end

    private

    def valid?
      @errors.empty? && @actions.all?(&:validate)
    end

    def initialize(project_name, actions_list)
      @errors = []
      @actions = []

      actions_list.each do |action_params|
        action_class = "Magma::#{action_params[:action_name].classify}Action".safe_constantize

        if action_class
          @actions << action_class.new(project_name, action_params)
        else
          @errors << ActionError.new(
            message: "Invalid action type",
            source: action_params[:action_name]
          )
        end
      end
    end
  end
end
