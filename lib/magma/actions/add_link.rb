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
          :link_types_valid,
      ]
    end

    def project
      Magma.instance.get_project(@project_name)
    end

    def two_links
      unless @action_params[:links].is_a?(Array)
        @errors << Magma::ActionError.new(
            message: 'links must be an array',
            source: @action_params.slice(:action_name, :links)
        )
        return
      end

      unless @action_params[:links].length == 2
        @errors << Magma::ActionError.new(
            message: 'links must contain exactly two items',
            source: @action_params.slice(:action_name, :links)
        )
        return
      end

      unless @action_params[:links].all? { |v| v.is_a?(Hash) }
        @errors << Magma::ActionError.new(
            message: 'links entries must be objects',
            source: @action_params.slice(:action_name, :links)
        )
        return
      end

      unless @action_params[:links].all? { |v| v.slice(:model_name, :attribute_name, :type).values.all? }
        @errors << Magma::ActionError.new(
            message: 'links entries must contain model_name, attribute_name, and type',
            source: @action_params.slice(:action_name, :links)
        )
        return
      end

      @action_params[:links]
    end

    def link_types_valid
      return unless two_links

      unless two_links.all? { |v| ['collection', 'link'].include?(v[:type]) }
        @errors << Magma::ActionError.new(
            message: 'links type must be either another link or a collection',
            source: @action_params.slice(:action_name, :links)
        )
        return
      end

      unless two_links.any? { |v| v[:type] == 'link' }
        @errors << Magma::ActionError.new(
            message: 'links must include at least one link type',
            source: @action_params.slice(:action_name, :links)
        )
        return
      end
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
      actions = [
        LinkAddAttributeAction.new(@project_name, @action_params[:links][0].slice(:model_name, :attribute_name, :type).update({
          link_model_name: @action_params[:links][1][:model_name]
        })),
      ]

      unless @action_params[:links][0].slice(:model_name, :attribute_name) == @action_params[:links][1].slice(:model_name, :attribute_name)
        actions << LinkAddAttributeAction.new(@project_name, @action_params[:links][1].slice(:model_name, :attribute_name, :type).update({
            link_model_name: @action_params[:links][0][:model_name]
        }))
      end

      actions
    end
  end
end
