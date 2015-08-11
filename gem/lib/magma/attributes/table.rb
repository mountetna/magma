class Magma
  class TableAttribute < Attribute
    def schema_ok?
      true
    end

    def schema_unchanged? 
      true
    end

    def needs_column?
      nil
    end

    def tab_column?
      nil
    end

    def json_for record
      table = record.send(@name)
      table.map do |item|
        item.json_document
      end
    end

    def validate links, record, &block
      child_model = Magma.instance.get_model @name
      identity = child_model.attributes[child_model.identity]
      links.each do |link|
        next unless link && link.size > 0
        identity.validate link, record do |error|
          yield error
        end
      end
    end
  end
end
