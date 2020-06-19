class Magma
  class Censor
    attr_reader :model, :record_name
    def initialize(user, project_name)
      @user = user
      @project_name = project_name
    end

    def censored?(model, revisions)
      return unless restrict?

      if model.has_attribute?(:restricted)
        restricted_identifiers = model.where(
          model.identity => revisions.map(&:record_name).map(&:to_s),
          restricted: true
        ).select_map(model.identity)

        unless restricted_identifiers.empty?
          restricted_identifiers.each do |restricted_identifier|
            yield "Cannot revise restricted #{model.model_name} '#{restricted_identifier}'"
          end
        end
      end

      restricted_attributes = model.attributes.values
        .select(&:restricted).map(&:name)

      revisions.each do |revision|
        (restricted_attributes & revision.attribute_names).each do |attribute_name|
          yield "Cannot revise restricted attribute :#{ attribute_name } on #{model.model_name} '#{revision.record_name}'"
        end
      end
    end

    private

    def restrict?
      !@user.can_see_restricted?(@project_name)
    end
  end
end