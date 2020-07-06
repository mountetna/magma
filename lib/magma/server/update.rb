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

      @payload.add_records(model, model_revisions.map{ |rev| rev.to_payload(@user) })
    end

    @loader.dispatch_record_set
  rescue Magma::LoadFailed => m
    log(m.complaints)
    @errors.concat(m.complaints)
  end

  private

  def is_file_attribute(model, attribute)
    return model.attributes[attribute].is_a? Magma::FileAttribute
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

    copy_revisions = []

    @revisions.each do |model, model_revisions|
      model_revisions.each do |revision|

        revision.attribute_names.select {
          |attribute_name| is_file_attribute(revision.model, attribute_name)
        }.each do |attribute_name|
          # For the remove operations, have to figure
          #   out the "current" link name in Metis,
          #   using the stored Magma value.
          if !revision[attribute_name][:path] || revision[attribute_name][:path] == '::blank'
            retrieval = Magma::Retrieval.new(
              revision.model,
              [revision.record_name.to_s],
              [attribute_name],
              restrict: !@user.can_see_restricted?(@project_name)
            )

            retrieval.records.each do |record|
              # Only add a link to remove on Metis if a copy already exists.
              # If the attribute hasn't been set before, we'll ignore this.
              if record[attribute_name] && record[attribute_name][:path]
                # This Metis route isn't active yet, so don't do anything
                # link_revisions.push({
                #   source: "metis://#{@project_name}/magma/#{record[attribute_name][:path]}",
                #   dest: nil
                # })
              end
            end
          elsif revision[attribute_name][:path].start_with? 'metis://'
            copy_revisions.push({
              source: revision[attribute_name][:path],
              dest: "metis://#{@project_name}/magma/#{revision.to_loader[attribute_name][:filename]}"
            })
          end
        end
      end
    end

    if copy_revisions.length > 0 && Magma.instance.storage.instance_of?(Magma::Storage::Metis)
      execute_bulk_copy_on_metis(copy_revisions)
    end
  end

  def execute_bulk_copy_on_metis(revisions)
    host = Magma.instance.config(:storage).fetch(:host)

    client = Etna::Client.new(
      "https://#{host}",
      @user.token)

    bulk_copy_route = client.routes.find { |r| r[:name] == 'file_bulk_copy' }

    return unless bulk_copy_route

    # At some point, when Metis supports changing project names,
    # this parameter should be the old file project name (metis_file_location_parts[2]))
    # and the new project name in the HMAC headers should
    # be @project_name
    path = client.route_path(
      bulk_copy_route,
      project_name: @project_name)

    bulk_copy_params = {
      revisions: revisions
    }

    # Now populate the standard headers
    hmac_params = {
      method: 'POST',
      host: host,
      path: path,

      expiration: (DateTime.now + 10).iso8601,
      id: 'magma',
      nonce: SecureRandom.hex,
      headers: bulk_copy_params,
    }

    hmac = Etna::Hmac.new(Magma.instance, hmac_params)

    cgi_hash = CGI.parse(hmac.url_params[:query])
    cgi_hash.delete('X-Etna-Revisions') # this could be too long for URI

    hmac_params_hash = Hash[cgi_hash.map {|key,values| [key.to_sym, values[0]||true]}]
    client.send(
      'body_request',
      Net::HTTP::Post,
      hmac.url_params[:path] + '?' + URI.encode_www_form(cgi_hash),
      bulk_copy_params)

  rescue Etna::Error => e
    log(e.message)
    # We receive a stringified JSON error from Metis
    @errors.push(JSON.parse(e.message))
  end
end
