class Magma
  class DocumentAttribute < Attribute
    def initialize name, model, opts
      super
      @type = String
    end

    def tab_column?
      nil
    end

    def json_for record
      document = record.send(@name)
      if document.current_path && document.url
        {
          url: document.url,
          path: File.basename(document.current_path)
        }
      else
        nil
      end
    end
  end
end
