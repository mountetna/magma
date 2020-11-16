# This model should be a set of Files ... how to uniquely identify them?
# Perhaps Metis could pass back the MD5 hash of each file?
# Or we just use index of the array? Just index seems brittle...
# Or is this just like a Folder, where files don't have to be unique? So by index could work.

require_relative './file_serializer'

class Magma
  class FilesAttribute < Attribute
    def database_type
      :json
    end

    def serializer
      @serializer ||= FileSerializer.new(magma_model: @magma_model)
    end

    def revision_to_loader(record_name, files)
      loader_format = files.map { |revision| serializer.to_loader_format(record_name, revision) }
      [ name, loader_format ]
    end

    def revision_to_payload(record_name, files, user)
      serializer.to_payload_format(record_name, files, user)
    end

    def query_to_payload(data)
      serializer.to_query_payload_format(data)
    end

    def query_to_tsv(value)
      serializer.to_query_tsv_format(value)
    end

    def entry(file, loader)
      serializer.to_loader_entry_format(file)
    end
  end
end
