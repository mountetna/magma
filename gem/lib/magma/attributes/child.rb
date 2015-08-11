class Magma
  class ChildAttribute < Attribute
    include Magma::Link
    def schema_ok?
      true
    end

    def schema_unchanged? 
      true
    end

    def needs_column?
      nil
    end

    def json_for record
      link = record.send(@name)
      link ? { identifier: link.identifier, model: link_model_name } : nil
    end

    def entry_for value, document
      { }
    end

    def validate link, document, &block
      return unless link && link.size > 0
      identity = link_model.attributes[link_model.identity]
      identity.validate link, document do |error|
        yield error
      end
    end

    def update_link record, link
      link_model.update_or_create(link_model.identity => link) do |obj|
        obj[ :"#{@model.name.snake_case}_id" ] = record.id
      end
    end
  end
end
