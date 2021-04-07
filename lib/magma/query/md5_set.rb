require_relative "metis_metadata"

class Md5Set < MetisMetadata
  def [](file_path)
    super

    @requested_files[file_path] ? @requested_files[file_path][:file_hash] : nil
  end
end
