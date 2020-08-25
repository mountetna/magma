class Magma
  class FileSerializer

    def initialize(magma_model:, record_name:)
      @magma_model = magma_model,
      @record_name = record_name
    end

    def to_loader_format(record_name, file_hash)
      case file_hash[:path]
      when '::blank'
        return {
          location: '::blank',
          filename: '::blank',
          original_filename: '::blank'
        }
      when '::temp'
        return nil
      when %r!^metis://!
        return {
          location: file_hash[:path],
          filename: filename(record_name, file_hash[:path]),
          original_filename: file_hash[:original_filename]
        }
      else
        return {
          location: nil,
          filename: nil,
          original_filename: nil
        }
      end
    end

    def to_payload_format(record_name, file_hash, user)
      case file_hash[:path]
      when '::temp'
        return { path: temporary_filepath(user) }
      when '::blank'
        return { path: '::blank' }
      when %r!^metis://!
        _, value = to_loader_format(record_name, file_hash)
        return to_query_payload_format(value)
      when nil
        return nil
      end
    end

    def to_query_payload_format(file_hash)
      return nil unless file_hash

      path = file_hash[:filename]
      return nil unless path

      case path
      when '::blank'
        return { path: path }
      when '::temp'
        return { path: path }
      else
        return {
          url: Magma.instance.storage.download_url(@magma_model.project_name, path),
          path: path,
          original_filename: file_hash[:original_filename]
        }
      end
    end

    def to_query_tsv_format(file_hash)
      file = to_query_payload_format(file_hash)
      file ? file[:url] : nil
    end

    def to_loader_entry_format(value)
      [ column_name, value.to_json ]
    end

    private

    def filename(record_name, path)
      ext = path ? ::File.extname(path) : ''
      ext = '.dat' if ext.empty?
      "#{@magma_model.model_name}-#{record_name}-#{name}#{ext}"
    end

    def temporary_filepath(user)
      Magma.instance.storage.upload_url(
        @magma_model.project_name, "tmp/#{Magma.instance.sign.uid}", user)
    end
  end
end
