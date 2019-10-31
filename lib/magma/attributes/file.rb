class Magma
  class FileAttribute < Attribute
    def initialize(name, model, opts)
      super
      @type = String
    end

    def update(record, new_value)
      [ new_value ]
    end

    private

    def filename(record, path)
      ext = path ? ::File.extname(path) : 'dat'
      "#{@model.class.name.snake_case}-#{@attribute_name}-#{record.identifier}.#{ext}"
    end

    public

    def json_for record
      path = record[@name]
      return nil unless path

      path.is_a?(Array) ?
        {
          upload_url: Magma.instance.storage.upload_url(@model.project_name, *path)
        }
        :
        {
          url: Magma.instance.storage.download_url(@model.project_name, path),
          path: File.basename(path)
        }
    end

    def txt_for(record)
      file = json_for(record)
      file ? file[:url] : nil
    end
  end
end
