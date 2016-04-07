class Magma
  class CollectionAttribute < Attribute
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
      collection = record.send(@name)
      collection.map do |l|
        { identifier: l.identifier, model: @name.to_s.snake_case }
      end
    end

    def validate links, &block
      links.each do |link|
        next unless link
        link_identity.validate link do |error|
          yield error
        end
      end
    end

    def update_link record, links
      child_model = Magma.instance.get_model @name
      links.each do |link|
        next if link.blank?
        if child_model
          child_model.update_or_create(child_model.identity => link) do |obj|
            obj[ :"#{@model.name.snake_case}_id" ] = record.id
          end
        end
      end
    end
  end
end
