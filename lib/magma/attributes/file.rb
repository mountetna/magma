class Magma
  class FileAttribute < Attribute
    def initialize(name, model, opts)
      @type = String
      file_type = self.is_a?(Magma::ImageAttribute) ? :image : :file
      Magma.instance.storage.setup_uploader(model, name, file_type) 
      super
    end

    def revision_to_loader(record_name, new_value)
      case new_value
      when '::blank'
        return [ @name, '::blank' ]
      when '::temp'
        return nil
      when %r!^metis://!
        return [ @name, filename(record_name, new_value) ]
      else
        return nil
      end
    end

    def revision_to_payload(record_name, new_value)
      case new_value
      when '::temp'
        return [ @name, { path: '::temp' } ]
      else
        _, path = revision_to_loader(record_name, new_value)
        return [ @name, query_to_payload(path) ]
      end
    end

    def query_to_payload(path)
      return nil unless path

      case path
      when '::blank'
        return { path: path }
      when '::temp'
        return { path: path }
      else
        return {
          url: Magma.instance.storage.download_url(@model.project_name, path),
          path: path
        }
      end
    end

    def query_to_tsv(value)
      file = query_to_payload(value)
      file ? file[:url] : nil
    end

    private

    def filename(record_name, path)
      ext = path ? ::File.extname(path) : ''
      ext = '.dat' if ext.empty?
      "#{@model.model_name}-#{record_name}-#{@name}#{ext}"
    end
  end
end
