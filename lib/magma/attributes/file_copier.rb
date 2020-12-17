class Magma
  class FileCopier
    attr_reader :loader, :project_name, :attribute_copy_revisions
    def initialize(loader, project_name, attribute_copy_revisions)
      @loader = loader
      @project_name = project_name
      @attribute_copy_revisions = attribute_copy_revisions
    end

    def bulk_copy_files
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
