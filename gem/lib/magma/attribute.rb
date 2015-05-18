class Magma
  class Attribute
    DISPLAY_ONLY = [ :child, :collection ]
    attr_reader :name, :type, :desc
    def initialize name, model, opts
      @name = name
      @model = model
      @type = opts[:type]
      @desc = opts[:desc]
      @display_name = opts[:display_name]
      @hide = opts[:hide]
      @readonly = opts[:readonly]
      @unique = opts[:unique]
    end

    def read_only?
      @readonly
    end

    def shown?
      !@hide
    end

    def matches_schema_type? name=@name
      schema.has_key?(name) && is_type?(schema[name][:db_type])
    end

    def schema_ok?
      matches_schema_type?
    end

    def is_type? type
      true
    end

    def display_name
      @display_name || name.to_s.split(/_/).map(&:capitalize).join(' ')
    end

    def add_entry
      entry = [ "add_column :#{@name}, #{type.name}" ]
      if @unique
        entry.push "add_unique_constraint :#{@name}"
      end
      entry
    end

    def new_entry
      entry = [ "#{type.name} :#{@name}" ]
      if @unique
        entry.push "unique :#{@name}"
      end
      entry
    end

    private
    def schema
      @schema ||= Hash[Magma.instance.db.schema @model.table_name]
    end
  end

  class ForeignKeyAttribute < Attribute
    def schema_ok?
      name = :"#{@name}_id"
      matches_schema_type? name
    end

    def new_entry
      model = Magma.instance.get_model @name
      "foreign_key :#{@name}_id, :#{model.table_name}"
    end

    def add_entry
      model = Magma.instance.get_model @name
      "add_foreign_key :#{@name}_id, :#{model.table_name}"
    end
  end

  class ChildAttribute < Attribute
    def schema_ok?
      true
    end
  end

  class CollectionAttribute < Attribute
    def schema_ok?
      true
    end
  end

  class DocumentAttribute < Attribute
    def initialize name, model, opts
      super
      @type = String
    end
  end
end
