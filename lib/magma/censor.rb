class Magma
  class Censor
    attr_reader :model, :record_name
    def initialize(user, project_name)
      @user = user
      @project_name = project_name
    end

    def censored_reasons(model, record_set)
      reasons = []
      return reasons unless restrict?

      record_names = record_set.values.map(&:record_name).reject { |name| name =~ Magma::Loader::TEMP_ID_MATCH }

      unrestricted_identifiers = Magma::Question.new(
        @project_name,
        [
          model.model_name.to_s,
          [ '::identifier', '::in', record_names ],
          '::all',
          '::identifier'
        ],
        restrict: true,
        user: @user
      ).answer.map(&:last)

      existing_identifiers = Magma::Question.new(
          @project_name,
          [
              model.model_name.to_s,
              [ '::identifier', '::in', record_names ],
              '::all',
              '::identifier'
          ],
          restrict: false,
          user: @user
      ).answer.map(&:last)

      restricted_identifiers = existing_identifiers - unrestricted_identifiers

      unless restricted_identifiers.empty?
        restricted_identifiers.each do |restricted_identifier|
          reasons << "Cannot revise restricted #{model.model_name} '#{restricted_identifier}'"
        end
      end

      restricted_attributes = (model.attributes.values
        .select(&:restricted).map(&:name) +
        [:restricted] +
        model.date_shift_attributes.map do |attr|
          attr.name.to_sym
        end).uniq

      record_set.each do |record_name, revision|
        (restricted_attributes & revision.attribute_key).each do |attribute_name|
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
