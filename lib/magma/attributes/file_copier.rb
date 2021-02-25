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

      client.file_bulk_copy(
        project_name: project_name,
        revisions: revisions,
        signatory: Magma.instance
      )

      return nil

    rescue Etna::Error => e
      # We receive a stringified JSON error from Metis
      return JSON.parse(e.message)
    end
  end
end
