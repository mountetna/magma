require_relative './file_copier'
require_relative './file_serializer'

class Magma
  class FileCollectionAttribute < Attribute
    def database_type
      :json
    end

    def serializer
      @serializer ||= FileSerializer.new(magma_model: @magma_model, attribute: self)
    end

    def revision_to_loader(record_name, files)
      loader_format = files.each_with_index.map do |revision, index|
        serializer.to_loader_format(record_name, revision, index)
      end
      [ name, loader_format ]
    end

    def revision_to_payload(record_name, files, loader)
      payload_format = files.each_with_index.map do |file_hash, index|
        serializer.to_payload_format(record_name, file_hash, loader.user, index)
      end
      [name, payload_format ]
    end

    def query_to_payload(data)
      return nil unless data

      data.map do |datum|
        serializer.to_query_payload_format(datum)
      end
    end

    def query_to_tsv(files)
      return nil unless files

      files.map do |file|
        serializer.to_query_tsv_format(file)
      end
    end

    def entry(files, loader)
      entry_format = files.map do |file|
        serializer.to_loader_entry_format(file)
      end.compact  # Remove the ::temp `nil` values for the loader

      [ column_name, entry_format.to_json ]
    end

    def load_hook(loader, record_name, files, copy_revisions)
      return "Not all files have the required :path key." unless files.all? { |file| file&.dig(:path) }

      files.each_with_index do |file_revision, index|
        path = file_revision[:path]
        if path.start_with? 'metis://'
          copy_revisions[ path ] = "metis://#{project_name}/magma/#{serializer.filename(
            record_name: record_name,
            path: path,
            original_filename: file_revision[:original_filename],
            index: index)}"
        end
      end

      return nil
    end

    def self.type_bulk_load_hook(loader, project_name, attribute_copy_revisions)
      copier = FileCopier.new(loader, project_name, attribute_copy_revisions)
      copier.bulk_copy_files
    end
  end
end
