class Magma
  class TableAttribute < Attribute
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

    def tab_column?
      nil
    end

    def json_for record
      table = record.send(@name)
      table.map &:identifier
    end

    # since a table has to display the other model, we should eager load its
    # column dependencies
    def eager
      link_atts = link_model.eager_attributes
      link_atts.empty? ? @name : { @name => link_atts }
    end

    def update record, new_value
    end

    def validate links, &block
      links.each do |link|
        next unless link && link.size > 0
        link_identity.validate link do |error|
          yield error
        end
      end
    end
  end
end
