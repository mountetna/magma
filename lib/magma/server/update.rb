require 'logger'
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

        revision.attribute_names.each do |attribute|
          if is_file_attribute(revision.model, attribute)

            if !revision.to_loader[attribute]  # nil
              remove_copy_on_metis(revision, attribute)
            elsif revision.to_loader[attribute][:location].start_with? 'metis:'
              copy_file_on_metis(revision, attribute)
            elsif revision.to_loader[attribute][:location] == '::blank'
              remove_copy_on_metis(revision, attribute)
            end
          end
        end
      end
    end
  end

  def remove_copy_on_metis(revision, attribute)
    # First get the current value of the file attribute,
    #   so we can get the file extension.
    # When we need to construct the link filename
    #   in the format <model>-<record_name>-stats.<ext>,
    #   so we can construct the right URL on Metis.
    # Then call the Metis "remove" route.
    return
  end

  def copy_file_on_metis(revision, attribute)
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
    metis_file_location_parts = revision.to_loader[attribute][:location].split('/')
    new_file_name = revision.to_loader[attribute][:filename]

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
      method: 'post',
      host: host,
      path: path,

      expiration: (DateTime.now + 10).iso8601,
      id: 'magma',
      nonce: SecureRandom.hex,
      headers: copy_params,
    }

    hmac = Etna::Hmac.new(Magma.instance, hmac_params)
    full_path = hmac.url_params[:path] + '?' + hmac.url_params[:query]
    client.send('post', full_path, copy_params)
  rescue Etna::Error => e
    log(e)
  end
end
