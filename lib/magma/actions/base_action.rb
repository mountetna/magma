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
      end

      @errors.empty?
    end

    def perform
      raise NotImplementedError
    end

    def rollback
    end

    def errors
      @errors.map(&:to_h)
    end

    private

    def validations
      []
    end

    def project
      @project ||= Magma.instance.get_project(@project_name)
    end
  end
end
