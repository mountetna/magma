class Magma
  class AddLinkAction < ComposedAction
    # Normally, add attributes validate against type: link, but this containing action allows it through
    # a special subclass.  Hiding it undernear the AddLinkAction namespace prevents it from being directly usable via
    # model_update_actions.rb
    class LinkAddAttributeAction < AddAttributeAction
      def validate_not_link
        # Do not actually validate the type, it will be handled directly by make_actions.
      end
    end

    def validations
      [
          :two_links,
          :link_types_valid,
      ]
    end

    def project
      Magma.instance.get_project(@project_name)
    end

    def two_links
      return unless (
      @action_params[:links].is_a? Array &&
          @action_params[:links].length == 2 &&
          @action_params[:links].all? { |v| v.is_a? Hash } &&
          @action_params[:links].all? { |v| v.slice(:model_name, :attribute_name, :type).values.all? }
      )

      @errors << Magma::ActionError.new(
          message: 'links must be an array of two valid link attribute hashes containing a model_name, attribute_name, and type',
          source: @action_params.slice(:action_name, :links)
      )
    end

    def link_types_valid
      return unless (
          @action_params[:links].all? { |v| ['collection', 'link'].include?(v[:type]) } &&
          @action_params[:links].any? { |v| v[:type] == 'link' }
      )

      @errors << Magma::ActionError.new(
          message: 'links type must include one link, and either another link or a collection',
          source: @action_params.slice(:action_name, :links)
      )
    end

    def two_model_names
      return unless (
          @action_params[:model_names].is_a? Array &&
          @action_params[:model_names].length == 2 &&
          @action_params[:model_name].all? { |model_name| project.models.include?(model_name.to_sym) }
      )

      @errors << Magma::ActionError.new(
          message: 'model_names must be an array of two valid model strings',
          source: @action_params.slice(:action_name, :model_names)
      )
    end

    def make_actions
      [
          AddLinkAction.new(@project_name, @action_params[:links][0].slice(:model_name, :attribute_name, :type).update({
              link_model_name: @action_params[:links][1][:model_name]
          })),
          AddLinkAction.new(@project_name, @action_params[:links][1].slice(:model_name, :attribute_name, :type).update({
              link_model_name: @action_params[:links][0][:model_name]
          })),
      ]
    end
  end
end
