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

    def rollback
    end

    def errors
      @errors.map(&:to_h)
    end

    private

    def validations
      []
    end
  end
end