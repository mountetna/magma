require_relative 'controller'

class UpdateController < Magma::Controller
  def action
    add_redact_keys(dateshift_redact_keys)

    @loader = Magma::Loader.new(@user,@project_name)
    @revisions = @params[:revisions]

    payload = load_revisions

    return success_json(payload.to_hash) if success?

    return failure(422, errors: @errors)
  end

  private

  def load_revisions
    @revisions.each do |model_name, model_revisions|
      model = Magma.instance.get_model(@project_name, model_name)

      model_revisions.each do |record_name, revision|
        @loader.push_record(model, record_name.to_s, revision)
        @loader.push_links(model, record_name, revision)
      end
    end

    @loader.push_implicit_link_revisions(@revisions)

    return @loader.dispatch_record_set
  rescue Magma::LoadFailed => m
    log(m.complaints)
    @errors.concat(m.complaints)
    return nil
  end

  def dateshift_redact_keys
    # Make sure the keys are symbols?
    [].tap do |redact_keys|
      Magma.instance.get_project(@project_name).models.each do |model_name, model|
        model.attributes.values.select do |attr|
          attr.is_a?(Magma::ShiftedDateTimeAttribute)
        end.each do |attr|
          redact_keys << attr.name.to_sym
        end
      end
    end
  end
end
