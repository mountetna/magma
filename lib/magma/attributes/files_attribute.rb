# This model should be a set of Files ... how to uniquely identify them?
# Perhaps Metis could pass back the MD5 hash of each file?
# Or we just use index of the array? Just index seems brittle...
# Or is this just like a Folder, where files don't have to be unique? So by index could work.

require_relative './file_serializer'

class Magma
  class FilesAttribute < Attribute
    def initialize(opts = {})
      super
      @serializer = FileSerializer.new(magma_model: @magma_model)
    end

    def database_type
      :json
    end

    def revision_to_loader(record_name, new_value)
      loader_format = new_value.map { |revision| @serializer.to_loader_format(record_name, revision) }
      [ name, loader_format ]
    end

    def revision_to_payload(record_name, new_value, user)
      @serializer.to_payload_format(record_name, new_value, user)
    end

    def query_to_payload(data)
      @serializer.to_query_payload_format(data)
    end

    def query_to_tsv(value)
      @serializer.to_query_tsv_format(value)
    end

    def entry(value, loader)
      @serializer.to_loader_entry_format(value)
    end
  end
end
