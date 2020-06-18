class Magma
  class FileAttribute < Attribute
    def database_type
      String
    end

    def update_record(record, new_value)
      super
      record.modified!(name)

      return record[name]
    end

    private

    def after_magma_model_set
      file_type = self.is_a?(Magma::ImageAttribute) ? :image : :file
      Magma.instance.storage.setup_uploader(@magma_model, attribute_name, file_type)
    end

    def filename(record, path)
      ext = path ? ::File.extname(path) : 'dat'
      "#{@magma_model.class.name.snake_case}-#{attribute_name}-#{record.identifier}.#{ext}"
    end

    public

    def json_for record
      path = record[name]
      return nil unless path

      path.is_a?(Array) ?
        {
          upload_url: Magma.instance.storage.upload_url(@magma_model.project_name, *path)
        }
        :
        {
          url: Magma.instance.storage.download_url(@magma_model.project_name, path),
          path: File.basename(path)
        }
    end

    def txt_for(record)
      file = json_for(record)
      file ? file[:url] : nil
    end
  end
end
