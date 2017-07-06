class Magma
  class DocumentAttribute < Attribute
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
      document = record.send(@name)
      if document.current_path && document.url
        {url: document.url, path: File.basename(document.current_path)}
      else
        nil
      end
    end

    def txt_for(record)
      document = json_for(record)
      document ? document[:url] : nil
    end
  end
end
