class Magma
  class ForeignKeyAttribute < Attribute
    include Magma::Link
    def self.options
      [ :column_type ] + superclass.options
    end

    def column_name
      :"#{link_model_name}_id"
    end

    def column_type_name
      :"#{link_model_name}_type"
    end

    # you can't change types for keys
    def schema_unchanged? 
      true
    end

    def entry migration, mode
      if @column_type
        [
          migration.column_entry(:"#{link_model_name}_id", Integer, mode),
          migration.column_entry(:"#{link_model_name}_type", String, mode),
          migration.index_entry([ :"#{link_model_name}_id", :"#{link_model_name}_type" ], mode)
        ]
      else
        migration.foreign_key_entry link_model_name, link_model, mode
      end
    end

    def json_for record
      link = record.send(@name)
      link ? { identifier: link.identifier, model: foreign_model_name(record).to_s.snake_case } : nil
    end

    def entry_for value, document
      # you need to find the foreign entity
      return {} if value.nil?
      if (fmodel = foreign_model(document))
        entry = {}
        if value.is_a? Magma::TempId
          entry = {
            column_name => value.real_id
          }
        elsif (foreign_record = fmodel[fmodel.identity => value])
          entry = {
            column_name => foreign_record[:id]
          }
          if @column_type
            entry[ column_type_name ] = foreign_model_name(document).to_s
          end
        end
        entry
      else
        raise Magma::LoadFailed.new(["Could not get foreign model for #{@name} and #{value}"])
      end
    end

    def validate link, document, &block
      return if link.is_a? Magma::TempId
      if fmodel = foreign_model(document)
        if identity = fmodel.attributes[fmodel.identity]
          identity.validate(link, document) do |error|
            yield error
          end
        end
      else
        yield "Could not find a model of type '#{name}' to validate for #{document}"
      end
    end

    def update_link record, link
      if link.nil?
        self[ column_name ] = nil
        return
      end

      if fmodel = foreign_model(record)
        fmodel.update_or_create(fmodel.identity => link) do |obj|
          record[ column_name ] = obj.id
          if @column_type
            record[ column_type_name ] = foreign_model_name(record).to_s
          end
        end
      end
    end

    private
    def foreign_model record
      model = Magma.instance.get_model(foreign_model_name(record))
      model if model < Magma::Model
    end

    def foreign_model_name document
      if @column_type
        if document.is_a? Hash
          record = @model[@model.identity => document[@model.identity]]
          return @model.send(@column_type, record)
        else
          return @model.send(@column_type, document)
        end
      else
        return link_model_name
      end
    end
  end
end
