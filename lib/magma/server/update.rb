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

    # Unclear if this step to update file links in Metis should
    # happen before load_revisions ... either could fail, which
    # should cause the other to not run.
    update_any_file_links if success?

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

  private

  def is_file_attribute(model, attribute)
    return model.attributes[attribute].instance_of? Magma::FileAttribute
  end

  def update_any_file_links
    # Here, if there are any File attributes in the revisions,
    #   we'll send a request to the Metis "copy" route, using the
    #   Etna::Client.
    # For ::blank or ::nil revisions, we remove the link in Metis.
    # Assumes a conversion to Metis storage and no other
    #   provider will be set.

    # Etna::Client.new throws an exception if the host config includes protocol,
    # i.e. https://metis-dev.etna-development.org will throw an exception
    # raise Etna::BadRequest, 'Storage host should not include protocol' if
    #   Magma.instance.config(:storage).fetch(:host).start_with? 'http'

    @revisions.each do |model, model_revisions|
      model_revisions.each do |revision|

        revision.attribute_names.select {
          |attribute_name| is_file_attribute(revision.model, attribute_name)
        }.each do |attribute_name|
          if !revision[attribute_name]  # nil
            remove_copy_on_metis(revision, attribute_name)
          elsif revision[attribute_name].start_with? 'metis:'
            copy_file_on_metis(revision, attribute_name)
          elsif revision[attribute_name] == '::blank'
            remove_copy_on_metis(revision, attribute_name)
          end
        end
      end
    end
  end

  def remove_copy_on_metis(revision, attribute_name)
    # First get the current value of the file attribute,
    #   so we can get the file extension.
    # When we need to construct the link filename
    #   in the format <model>-<record_name>-stats.<ext>,
    #   so we can construct the right URL on Metis.
    # Then call the Metis "remove" route.
    return
  end

  def copy_file_on_metis(revision, attribute_name)
    host = Magma.instance.config(:storage).fetch(:host)

    client = Etna::Client.new(
      "https://#{host}",
      @user.token)

    copy_route = client.routes.find { |r| r[:name] == 'file_copy' }

    return unless copy_route

    # We need to make an assumption that the Metis path follows
    # a convention of
    #   metis://<project>/<bucket>/<folder path>/<file name>
    # Splitting the above produces
    #   ["metis", "", "<project>", "<bucket>", "<folder path>" ... "file name"]
    metis_file_location_parts = revision[attribute_name].split('/')

    # We need the filename here, so we call to_loader
    new_file_name = revision.to_loader[attribute_name][:filename]

    # At some point, when Metis supports changing project names,
    # this parameter should be the old file project name (metis_file_location_parts[2]))
    # and the new project name in the HMAC headers should
    # be @project_name
    path = client.route_path(
      copy_route,
      project_name: @project_name,
      bucket_name: metis_file_location_parts[3],
      file_path: metis_file_location_parts[4..-1].join('/'))

    copy_params = {
      new_bucket_name: 'magma',
      new_file_path: new_file_name
    }

    # Now populate the standard headers
    hmac_params = {
      method: 'POST',
      host: host,
      path: path,

      expiration: (DateTime.now + 10).iso8601,
      id: 'magma',
      nonce: SecureRandom.hex,
      headers: copy_params,
    }

    hmac = Etna::Hmac.new(Magma.instance, hmac_params)

    # For the params to show up on the other end in Metis,
    #   need to include them in the request body. For POST
    #   requests, the URL query params are ignored and
    #   won't make it to the receiving route.
    hmac_params = Rack::Utils.parse_query(
      hmac.url_params[:query]).map { |k,v| [k.to_sym, v] }.to_h

    client.send('post', hmac.url_params[:path], copy_params.merge(hmac_params))
  end
end
