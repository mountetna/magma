require 'securerandom'

class Magma
  class FileAttribute < Attribute
    def initialize(name, model, opts)
      opts.merge!(type: :json)
      super
    end

    def revision_to_loader(record_name, new_value)
      case new_value[:path]
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
          location: new_value[:path],
          filename: filename(record_name, new_value[:path]),
          original_filename: new_value[:original_filename]
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
      case new_value[:path]
      when '::temp'
        return [ @name, { path: temporary_filepath } ]
      when '::blank'
        return [ @name, { path: '::blank' } ]
      when %r!^metis://!
        _, value = revision_to_loader(record_name, new_value)
        return [ @name, query_to_payload(value) ]
      when nil
        return [ @name, nil ]
      end
    end

    def query_to_payload(data)
      path = data[:filename]
      return nil unless path

      case path
      when '::blank'
        return { path: path }
      when '::temp'
        return { path: path }
      else
        return {
          url: Magma.instance.storage.download_url(@model.project_name, path),
          path: path,
          original_filename: data[:original_filename]
        }
      end
    end

    def query_to_tsv(value)
      file = query_to_payload(value)
      file ? file[:url] : nil
    end

    def entry(value, loader)
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
