require 'pry'
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

    update_any_file_links if success?

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

  def load_revisions
    @revisions.each do |model, model_revisions|
      model_revisions.each do |revision|
        @loader.push_record(model, revision.to_loader)

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

  def update_any_file_links
    # Here, if there are any File attributes in the revisions and
    #   the storage is configured to use Metis instead of AWS,
    #   we'll send a request to the Metis "copy" route, using the
    #   Etna::Client.
    if Magma.instance.config(:storage).fetch(:provider).downcase == 'metis'

      # Etna::Client.new throws an exception if the host config includes protocol,
      # i.e. https://metis-dev.etna-development.org will throw an exception
      raise Etna::BadRequest, 'Storage host should not include protocol' if
        Magma.instance.config(:storage).fetch(:host).start_with? 'http'

      # Do we get the token from config?
      client = Etna::Client.new(
        "https://#{Magma.instance.config(:storage).fetch(:host)}",
        Magma.instance.config(:token) ? Magma.instance.config(:token) : 'token')

      @revisions.each do |model, model_revisions|
        model_revisions.each do |revision|

          # The below test seems brittle -- anything better?
          if revision.to_loader.key?(:stats)
            # copy_url = Magma.instance.storage.copy_url(
            #   @project_name,
            #   revision.to_payload[:stats][:path]  <-- this way seems brittle. What would be better?
            # )

            # Use the Etna::Client to make a POST call to Metis's copy_url?
          end
        end
      end
    end
  end
end
