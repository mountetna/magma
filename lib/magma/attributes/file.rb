require 'securerandom'

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
        return [ @name, {
          location: '::blank',
          filename: '::blank',
          original_filename: '::blank'
        }]
      when '::temp'
        # Here we should generate a temporary location on Metis
        return nil
      when %r!^metis://!
        return [ @name, {
          location: new_value,
          filename: filename(record_name, new_value),
          original_filename: new_value.split('/')[-1]
        }]
      else
        # return nil --> This didn't seem to save to the database?
        return [ @name, {
          location: nil,
          filename: nil,
          original_filename: nil
        }]
      end
    end

    def revision_to_payload(record_name, new_value)
      case new_value
      when '::temp'
        return [ @name, { path: temporary_filepath } ]
      when '::blank'
        return [ @name, { path: '::blank' } ]
      when %r!^metis://!
        _, value = revision_to_loader(record_name, new_value)
        return [ @name, query_to_payload(value[:filename]) ]
      when nil
        return [ @name, nil ]
      end
    end

    def query_to_payload(path)
      return nil unless path

      case JSON.parse(path)[:filename]
      when '::blank'
        return { path: path }
      when '::temp'
        return { path: path }
      else
        # Do we need to / want to return the original filename here?
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

    def entry(value, loader)
      # value is a hash, from revision_to_loader?
      [ name, value.to_json ]
    end

    private

    def filename(record_name, path)
      ext = path ? ::File.extname(path) : ''
      ext = '.dat' if ext.empty?
      "#{@model.model_name}-#{record_name}-#{@name}#{ext}"
    end

    def temporary_filepath
      Magma.instance.storage.upload_url(
        @model.project_name, "tmp/#{SecureRandom.uuid}")
    end
  end
end
