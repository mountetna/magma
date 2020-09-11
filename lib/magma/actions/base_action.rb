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

  class NoOpAction < BaseAction
    def perform
      true
    end
  end

  class ComposedAction < BaseAction
    def make_actions
      []
    end

    def inner_actions
      @inner_actions ||= make_actions
    end

    def perform
      inner_actions.each do |action|
        result = action.perform
        @errors.push(*action.errors)
        return false unless result
      end

      @errors.empty?
    end

    def validate
      inner_actions.each do |action|
        action.validate
        @errors.push(*action.errors)
      end

      super
    end
  end
end
