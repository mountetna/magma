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
      link ? link.identifier : nil
    end

    def eager
      @name
    end

    def entry_for value
      nil
    end

    def validate link, &block
      return unless link && link.size > 0
      link_identity.validate link do |error|
        yield error
      end
    end

    def update record, link
      link_model.update_or_create(link_model.identity => link) do |obj|
        obj[ self_id ] = record.id
      end
    end
  end
end
