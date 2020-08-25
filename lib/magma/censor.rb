class Magma
  class Censor
    attr_reader :model, :record_name
    def initialize(user, project_name)
      @user = user
      @project_name = project_name
    end

    def censored?(model, revisions)
      censored_reasons(model, revisions).length > 0
    end

    def censored_reasons(model, revisions)
      reasons = []
      return reasons unless restrict?

      record_names = revisions.map(&:record_name).map(&:to_s)

      restricted_identifiers = record_names - Magma::Question.new(
        @project_name,
        [
          model.model_name.to_s,
          [ '::identifier', '::in', record_names ],
          '::all',
          '::identifier'
        ],
        restrict: true
      ).answer.map(&:last)

      unless restricted_identifiers.empty?
        restricted_identifiers.each do |restricted_identifier|
          reasons << "Cannot revise restricted #{model.model_name} '#{restricted_identifier}'"
        end
      end

      restricted_attributes = model.attributes.values
        .select(&:restricted).map(&:name) + [:restricted]

      revisions.each do |revision|
        (restricted_attributes & revision.attribute_names).each do |attribute_name|
          reasons << "Cannot revise restricted attribute :#{ attribute_name } on #{model.model_name} '#{revision.record_name}'"
        end
      end

      reasons
    end

    private

    def restrict?
      !@user.can_see_restricted?(@project_name)
    end
  end
end
