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

  def update_any_file_links
    # Here, if there are any File attributes in the revisions,
    #   we'll send a request to the Metis "copy" route, using the
    #   Etna::Client.
    # Assumes a conversion to Metis storage and no other
    #   provider will be set.

    # Etna::Client.new throws an exception if the host config includes protocol,
    # i.e. https://metis-dev.etna-development.org will throw an exception
    # raise Etna::BadRequest, 'Storage host should not include protocol' if
    #   Magma.instance.config(:storage).fetch(:host).start_with? 'http'

    auth = Etna::Auth.new(:magma)

    host = Magma.instance.config(:storage).fetch(:host)

    client = Etna::Client.new(
      "https://#{host}",
      @request.cookies[Magma.instance.config(:token_name)] || auth.send('auth', *[@request, :magma]))

    copy_route = ''

    client.routes.each do |route|
      if route[:name] == 'copy'
        copy_route = route
        break
      end
    end

    if copy_route == ''
      return
    end

    @revisions.each do |model, model_revisions|
      model_revisions.each do |revision|

        # The below test for :stats as a File indicator seems
        #   brittle -- anything better?
        if revision.to_loader.key?(:stats)
          path = client.send('route_path', *[copy_route, {:project_name => "foo", :bucket_name => "magma", :file_path => "test.txt"}])

          hmac_signature = auth.send('etna_param', *[@request, :signature])

          return false unless hmac_signature

          return false unless headers = auth.send('etna_param', *[@request, :headers])

          headers = headers.split(/,/).map do |header|
            [ header.to_sym, auth.send('etna_param', *[@request, header]) ]
          end.to_h

          # Now expect the standard headers
          hmac_params = {
            method: 'post',
            host: host,
            path: path,

            expiration: auth.send('etna_param', *[@request, :expiration]),
            id: auth.send('etna_param', *[@request, :id]),
            nonce: auth.send('etna_param', *[@request, :nonce]),
            headers: headers,
            test_signature: hmac_signature
          }

          hmac = Etna::Hmac.new(application, hmac_params)

          # request.env['etna.hmac'] = hmac

          return nil unless hmac.valid?

          client.post(hmac.url_params[:path], hmac.url_params[:query])
        end
      end
    end
  end
end
