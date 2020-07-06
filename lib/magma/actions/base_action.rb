require_relative 'action_error'

class Magma
  class BaseAction
    def initialize(project_name, action_params = {})
      @project_name = project_name
      @action_params = action_params
      @errors = []
    end

    def validate
      validations.each do |validation|
        send(validation)
        break if @errors.any?
      end

      @errors.empty?
    end

    def perform
      raise NotImplementedError
    end

    def errors
      @errors.map(&:to_h)
    end

    private

    def validations
      [:validate_project] + action_validations
    end

    def action_validations
      []
    end

    def validate_project
      return if Magma.instance.get_project(@project_name)

      @errors << Magma::ActionError.new(
        message: 'Project does not exist',
        source: @project_name
      )
    end
  end
end
