require_relative './file_serializer'

class Magma
  class FileAttribute < Attribute
    def database_type
      :json
    end

    def serializer
      @serializer ||= FileSerializer.new(magma_model: @magma_model)
    end

    def revision_to_loader(record_name, file)
      loader_format = serializer.to_loader_format(record_name, file)
      loader_format ? [ name, loader_format ] : nil
    end

    def revision_to_payload(record_name, new_value, loader)
      [name, serializer.to_payload_format(record_name, new_value, user) ]
    end

    def query_to_payload(data)
      serializer.to_query_payload_format(data)
    end

    def query_to_tsv(file)
      serializer.to_query_tsv_format(file)
    end

    def entry(file, loader)
      serializer.to_loader_entry_format(file)
    end

    def load_hook(loader, record_name, file, copy_revisions)
      return nil unless path = file&.dig(:path)

      if path.start_with? 'metis://'
        copy_revisions[ path ] = "metis://#{project_name}/magma/#{serializer.filename(record_name, path, file[:original_filename])}"
      end

      return nil
    end

    def self.type_bulk_load_hook(loader, project_name, attribute_copy_revisions)
      revisions = attribute_copy_revisions.values.map(&:to_a).flatten(1).map{|rev|
        {source: rev[0], dest: rev[1]}}

      host = Magma.instance.config(:storage).fetch(:host)

      client = Etna::Client.new("https://#{host}", loader.user.token)

      bulk_copy_route = client.routes.find { |r| r[:name] == 'file_bulk_copy' }

      return nil unless bulk_copy_route

      # At some point, when Metis supports changing project names,
      # this parameter should be the old file project name (metis_file_location_parts[2]))
      # and the new project name in the HMAC headers should
      # be project_name

      path = client.route_path(
        bulk_copy_route,
        project_name: project_name
      )

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

      return nil

    rescue Etna::Error => e
      # We receive a stringified JSON error from Metis
      return JSON.parse(e.message)
    end
  end
end
