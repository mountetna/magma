class Magma
  class FileAttribute < Attribute
    def initialize(project, name, model, opts)
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
      file = record.send(@name)
      if file.current_path && file.url
        {
          url: file.url,
          path: File.basename(file.current_path)
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
