class Magma
  class ForeignKeyAttribute < Attribute
    include Magma::Link

    # you can't change types for keys
    def schema_unchanged? 
      true
    end

    def column_name
      foreign_id
    end

    def entry migration, mode
      migration.foreign_key_entry @name, link_model, mode
    end

    def eager
      @name
    end

    def json_for record
      link = record.send(@name)
      link ? link.identifier : nil
    end

    def entry_for value
      # you need to find the foreign entity
      return {} if value.nil?
      entry = {}

      if value.is_a? Magma::TempId
        entry = {
          foreign_id => value.real_id
        }
      elsif foreign_record = link_record(value)
        entry = {
          foreign_id => foreign_record[:id]
        }
      end
    end

    def validate link, &block
      return if link.is_a? Magma::TempId
      if link_identity
        link_identity.validate(link) do |error|
          yield error
        end
      end
    end

    def update record, link
      if link.nil?
        record[ foreign_id ] = nil
        return
      end

      link_model.update_or_create(link_model.identity => link) do |obj|
        record[ foreign_id ] = obj.id
      end
    end
  end
end
