require_relative "./with_update_model_module"

class Magma
  class AddDictionaryAction < BaseAction
    include WithUpdateModel

    # Action to add a dictionary definition to an existing model.
    # NOTE: This will only work for DB-defined models, not legacy models.
    def perform
      return false if @errors.any?

      save_dictionary
      model.dictionary(@action_params[:dictionary])
      true
    end

    private

    def save_dictionary
      Magma.instance.db[:models].where(
        project_name: @project_name,
        model_name: @action_params[:model_name]).update(
        dictionary: JSON.generate(@action_params[:dictionary])
      )
    end

    def validations
      [
        :validate_model,
        :validate_db_model,
        :validate_model_attribute_names,
        :validate_dictionary_model,
        :validate_dictionary_attribute_names,
      ]
    end

    def validate_dictionary_model
      @errors << Magma::ActionError.new(
        message: 'Must include :dictionary_model in :dictionary.',
        source: @action_params.slice(:action_name, :dictionary)
      ) unless @action_params[:dictionary][:dictionary_model]

      @errors << Magma::ActionError.new(
        message: 'Dictionary model does not exist.',
        source: @action_params.slice(:action_name, :dictionary)
      ) unless dictionary_model
    end

    def validate_model_attribute_names
      return unless model

      @action_params[:dictionary].symbolize_keys.keys.reject do |key|
        :dictionary_model == key
      end.each do |key|
        @errors << Magma::ActionError.new(
          message: "attribute_name \"#{key}\" does not exist on \"#{model.name}\".",
          source: @action_params.slice(:project_name, :model_name, :dictionary)
        ) if !model&.has_attribute?(key)
      end
    end

    def validate_dictionary_attribute_names
      return unless dictionary_model

      @action_params[:dictionary].symbolize_keys.keys.reject do |key|
        :dictionary_model == key
      end.each do |key|
        dictionary_key = @action_params[:dictionary][key]

        @errors << Magma::ActionError.new(
          message: "attribute_name \"#{dictionary_key}\" does not exist on dictionary \"#{dictionary_model.name}\".",
          source: @action_params.slice(:project_name, :model_name, :dictionary)
        ) if !dictionary_model&.has_attribute?(dictionary_key)
      end
    end

    def dictionary_model
      return @dictionary_model if defined? @dictionary_model

      @dictionary_model = begin
        Magma.instance.get_model(
          @project_name,
          @action_params[:dictionary][:dictionary_model].split('::').last.downcase)
      rescue
        nil
      end
    end
  end
end
