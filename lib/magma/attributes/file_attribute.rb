require_relative './file_copier'
require_relative './file_serializer'

class Magma
  class FileAttribute < Attribute
    def database_type
      :json
    end

    def serializer
      @serializer ||= FileSerializer.new(magma_model: @magma_model, attribute: self)
    end

    def revision_to_loader(record_name, file)
      loader_format = serializer.to_loader_format(record_name, file)
      [ name, loader_format ]
    end

    def revision_to_payload(record_name, new_value, loader)
      [name, serializer.to_payload_format(record_name, new_value, loader.user) ]
    end

    def query_to_payload(data)
      return nil unless data

      serializer.to_query_payload_format(data)
    end

    def query_to_tsv(file)
      serializer.to_query_tsv_format(file)
    end

    def entry(file, loader)
      [ column_name, serializer.to_loader_entry_format(file).to_json ]
    end

    def load_hook(loader, record_name, file, copy_revisions)
      return nil unless path = file&.dig(:path)

      if path.start_with? 'metis://'
        copy_revisions[ path ] = "metis://#{project_name}/magma/#{serializer.filename(record_name: record_name, path: path, original_filename: file[:original_filename])}"
      end

      return nil
    end

    def self.type_bulk_load_hook(loader, project_name, attribute_copy_revisions)
      return FileCopier.new(loader, project_name, attribute_copy_revisions).bulk_copy_files
    end
  end
end
