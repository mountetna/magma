require_relative './file_serializer'

class Magma
  class FileAttribute < Attribute
    def initialize(opts = {})
      super
      @serializer = FileSerializer.new(magma_model: @magma_model)
    end

    def database_type
      :json
    end

    def revision_to_loader(record_name, new_value)
      loader_format = @serializer.to_loader_format(name, record_name, new_value)
      loader_format ? [ name, loader_format ] : nil
    end

    def revision_to_payload(record_name, new_value, user)
      [name, @serializer.to_payload_format(record_name, new_value, user) ]
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
