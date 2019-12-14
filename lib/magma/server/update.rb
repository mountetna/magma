require_relative 'controller'

class UpdateController < Magma::Controller
  def action
    @loader = Magma::Loader.new
    @censor = Magma::Censor.new(@user,@project_name)
    @payload = Magma::Payload.new

    @revisions = @params[:revisions].map do |model_name, model_revisions|
      model = Magma.instance.get_model(@project_name, model_name)
      @payload.add_model(model)

      [
        model,
        model_revisions.map do |record_name, revision|
          Magma::Revision.new(model, record_name, revision)
        end
      ]
    end.to_h

    censor_revisions

    load_revisions if success?

    return success_json(@payload.to_hash) if success?

    return failure(422, errors: @errors)
  end

  private

  def censor_revisions
    @revisions.each do |model, model_revisions|
      @censor.censored?(model, model_revisions) do |error|
        @errors.push error
      end
    end
  end

  def censored_revisions(model, revisions)
    revisions.map do |record_name, revision|
      # don't allow restricted records to be 
      if @restrict
        if @model.has_attribute?(:restricted) && @record[:restricted]
          @errors.push "Cannot revise restricted #{@model.model_name} '#{@record.identifier}'"
        end

        revision.each do |attribute_name, value|
          if @model.has_attribute?(attribute_name) && @model.attributes[attribute_name].restricted
            @errors.push "Cannot revise restricted attribute :#{ attribute_name } on #{@model.model_name} '#{@record.identifier}'"
          end
        end
      end

      censored_revision = {
        model.identity => record_name
      }.merge(revision).select do |att_name|
        model.has_attribute?(att_name) && !model.attributes[att_name.to_sym].read_only?
      end
    end
  end

  # fill the loader with records and create a revision payload
  def load_revisions
    @revisions.each do |model, model_revisions|
      model_revisions.each do |revision|
        @loader.push_record(model, revision.to_update)

        revision.each_linked_record do |link_model, link_record|
          @loader.push_record(link_model, link_record)
        end
      end

      @payload.add_records(model, model_revisions.map(&:to_payload))
    end

    @loader.dispatch_record_set
  rescue Magma::LoadFailed => m
    log(m.complaints)
    @errors.concat(m.complaints)
  end
end
