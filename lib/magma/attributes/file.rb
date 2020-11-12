class Magma
  class FileAttribute < Attribute

    def database_type
      :json
    end

    def revision_to_loader(record_name, file)
      [ name, file.update(filename: filename(record_name, file[:path])) ]
    end

    def revision_to_payload(record_name, new_value, loader)
      case new_value[:path]
      when '::temp'
        return [ name, { path: temporary_filepath(loader.user) } ]
      when '::blank'
        return [ name, { path: '::blank' } ]
      when %r!^metis://!
        _, value = revision_to_loader(record_name, new_value)
        return [ name, query_to_payload(value) ]
      when nil
        return [ name, nil ]
      end
    end

    def query_to_payload(data)
      return nil unless data

      path = data[:filename]
      return nil unless path

      case path
      when '::blank'
        return { path: path }
      when '::temp'
        return { path: path }
      else
        return {
          url: Magma.instance.storage.download_url(@magma_model.project_name, path),
          path: path,
          original_filename: data[:original_filename]
        }
      end
    end

    def query_to_tsv(file)
      file ? file[:url] : nil
    end

    def entry(file, loader)
      value = case file[:path]
      when '::blank'
        {
          location: '::blank',
          filename: '::blank',
          original_filename: '::blank'
        }
      when '::temp'
        return nil
      when %r!^metis://!
        {
          location: file[:path],
          filename: file[:filename],
          original_filename: file[:original_filename]
        }
      else
        {
          location: nil,
          filename: nil,
          original_filename: nil
        }
      end

      [ column_name, value.to_json ]
    end

    def load_hook(loader, record_name, file, copy_revisions)
      return nil unless path = file&.dig(:path)

      if path.start_with? 'metis://'
        copy_revisions[ path ] = "metis://#{project_name}/magma/#{filename(record_name, path)}"
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

    private

    def filename(record_name, path)
      ext = path ? ::File.extname(path) : ''
      ext = '.dat' if ext.empty?
      "#{@magma_model.model_name}-#{record_name}-#{name}#{ext}"
    end

    def temporary_filepath(user)
      Magma.instance.storage.upload_url(
        @magma_model.project_name,
        "tmp-#{Magma.instance.sign.uid}",
        email: user.email,
        first: user.first,
        last: user.last
      )
    end
  end
end
