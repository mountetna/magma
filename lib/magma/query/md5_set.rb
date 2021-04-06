require_relative "metis_metadata"

class Md5Set < MetisMetadata
  def [](file_path)
    super

    @requested_files[file_path][:file_hash]
  end
end
