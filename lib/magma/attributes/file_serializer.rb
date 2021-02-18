class Magma
  class FileSerializer

    def initialize(magma_model:, attribute:)
      @magma_model = magma_model
      @attribute = attribute
    end

    def temp
      '::temp'
    end

    def blank
      '::blank'
    end

    def to_loader_format(record_name, file_hash, index=nil)
      loader_data = case file_hash[:path]
      when blank
        {
          location: blank,
          filename: blank,
          original_filename: blank
        }
      when temp
        {}
      when %r!^metis://!
        {
          location: file_hash[:path],
          filename: filename(
            record_name: record_name,
            path: file_hash[:path],
            original_filename: file_hash[:original_filename],
            index: index),
          original_filename: file_hash[:original_filename]
        }
      else
        {
          location: nil,
          filename: nil,
          original_filename: nil
        }
      end

      file_hash.update(loader_data)
    end

    def to_payload_format(record_name, file_hash, user, index=nil)
      case file_hash[:path]
      when temp
        return { path: temporary_filepath(user) }
      when blank
        return { path: blank }
      when %r!^metis://!
        value = to_loader_format(record_name, file_hash, index)
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
      when blank
        return { path: path }
      when temp
        return { path: path }
      else
        return {
          url: Magma.instance.storage.download_url(@magma_model.project_name, path).to_s,
          path: path,
          original_filename: file_hash[:original_filename]
        }
      end
    end

    def to_query_tsv_format(file)
      file ? file[:url] : nil
    end

    def to_loader_entry_format(file)
      case file[:path]
      when blank
        {
          location: blank,
          filename: blank,
          original_filename: blank
        }
      when temp
        return nil
      when %r!^metis://!
        {
          location: file[:path],
          filename: file[:filename],
          original_filename: file[:original_filename]
        }
      else
        {
          location: nil,
          filename: nil,
          original_filename: nil
        }
      end
    end

    def filename(record_name:, path:, original_filename: nil, index: nil)
      ext = path ? ::File.extname(path) : ''
      original_ext = original_filename ? ::File.extname(original_filename) : ''
      ext = original_ext if ext.empty?
      ext = '.dat' if ext.empty?

      return "#{@magma_model.model_name}-#{record_name}-#{@attribute.name}#{ext}" unless index

      "#{@magma_model.model_name}-#{record_name}-#{@attribute.name}-#{index}#{ext}"
    end

    private

    def temporary_filepath(user)
      Magma.instance.storage.upload_url(
        @magma_model.project_name,
        "tmp-#{Magma.instance.sign.uid}",
        email: user.email,
        name: user.name
      )
    end
  end
end
