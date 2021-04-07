require_relative "metis_metadata"

class UpdatedAtSet < MetisMetadata
  def [](file_path)
    super

    @requested_files[file_path] ? @requested_files[file_path][:updated_at] : nil
  end
end
