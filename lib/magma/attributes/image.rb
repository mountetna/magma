class Magma
  class ImageAttribute < Attribute
    def initialize(name, model, opts)
      super
      @type = String
    end

    def tab_column?
      nil
    end

    def update(record, new_value)
      super
      record.modified!(name)
    end

    def json_for record
      path = record[@name]
      if path
        thumb_path = File.join(File.dirname(path), "thumb_#{File.basename(path)}")
        {
          url: Magma.instance.storage.get_url(path),
          path: File.basename(path),
          thumb: Magma.instance.storage.get_url(thumb_path)
        }
      else
        nil
      end
    end
    
    def txt_for record
      image = json_for(record)
      image ? image[:url] : nil
    end
  end
end
