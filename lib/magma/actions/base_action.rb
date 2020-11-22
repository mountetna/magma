require_relative 'action_error'

class Magma
  class BaseAction
    def initialize(project_name, action_params = {})
      @project_name = project_name
      @action_params = action_params
      @errors = []
    end

    def target_models
      []
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
    alias :super_validate :validate

    def make_actions
      []
    end

    def target_models
      inner_actions.flat_map(&:target_models)
    end

    def inner_actions
      @inner_actions ||= begin
        super_validate ? make_actions : []
      end
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

      @errors.empty?
    end
  end
end
