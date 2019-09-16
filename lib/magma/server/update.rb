require_relative 'controller'

class UpdateController < Magma::Controller
  def action
    validate_revisions

    post_revisions if success?

    if success?
      success(revisions_payload.to_json, 'application/json')
    else
      failure(422, errors: @errors)
    end
  end

  private

  def revisions
    @revisions ||= 
      begin
        validator = Magma::Validation.new

        @params[:revisions].map do |model_name, model_revisions|
          model = Magma.instance.get_model(@project_name, model_name)

          model_revisions.map do |record_name, revision_data|
            Magma::Revision.new(model, record_name.to_s, revision_data, validator, !@user.can_see_restricted?(@project_name))
          end
        end.flatten
      end
  end

  def validate_revisions
    revisions.each do |revision|
      error(revision.errors) if !revision.valid?
    end
  end

  def post_revisions
    revisions.each do |revision|
      begin
        revision.post!
      rescue Magma::LoadFailed => m
        log m.complaints
        @errors.concat m.complaints
        next
      end
    end
  end

  def revisions_payload
    payload = Magma::Payload.new

    revisions.group_by(&:model).each do |model,model_revisions|
      attribute_names = model_revisions.first.attribute_names

      payload.add_model(model, attribute_names)

      records = model_revisions.map(&:updated_record)

      payload.add_records(model, records)
    end

    payload.to_hash
  end
end
