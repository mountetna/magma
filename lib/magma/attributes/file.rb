class Magma
  class FileAttribute < Attribute
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

    def json_for(record)
      path = record[@name]
      if path
        {
          url: '/', #Magma.instance.storage.get_url(path),
          path: '/'#File.basename(path)
        }
      else
        nil
      end
    end

    def txt_for(record)
      file = json_for(record)
      file ? file[:url] : nil
    end
  end
end
