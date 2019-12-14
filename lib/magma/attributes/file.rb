class Magma
  class FileAttribute < Attribute
    def initialize(name, model, opts)
      @type = String
      file_type = self.is_a?(Magma::ImageAttribute) ? :image : :file
      Magma.instance.storage.setup_uploader(model, name, file_type) 
      super
    end

    def update(record_name, new_value)
      [ @attribute_name, new_value ]
    end

    private

    def filename(record, path)
      ext = path ? ::File.extname(path) : 'dat'
      "#{@model.class.name.snake_case}-#{@attribute_name}-#{record.identifier}.#{ext}"
    end

    public

    def json_payload(path)
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

    def text_payload(value)
      file = json_payload(value)
      file ? file[:url] : nil
    end
  end
end
