require "set"

class MetisMetadata
  def initialize(user, model)
    @user = user
    @model = model

    @requested_file_paths = Set.new
  end

  class Value
    def initialize(set, file_path)
      @set = set
      @file_path = file_path
    end

    def to_json(options = {})
      @set[@file_path].to_json
    end

    def [](key)
      @set[@file_path] ? @set[@file_path][key] : nil
    end
  end

  def <<(file_path)
    @requested_file_paths << file_path
    return Value.new(self, file_path)
  end

  def [](file_path)
    unless @requested_files
      # make request to metis
      host = Magma.instance.config(:storage).fetch(:host)

      client = Etna::Client.new("https://#{host}", @user.token)

      response = client.bucket_find(
        project_name: @model.project_name.to_s,
        bucket_name: "magma",
        params: [{
          attribute: "name",
          predicate: "=",
          value: @requested_file_paths.to_a,
          type: "file",
        }],
        signatory: Magma.instance,
      )

      @requested_files = response[:files].map do |file|
        [file[:file_name], file]
      end.to_h
    end

    @requested_files[file_path]
  end
end
