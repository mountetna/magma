class Magma
  class Attribute
    DISPLAY_ONLY = [ :child, :collection ]
    attr_reader :name, :type, :desc, :loader
    def initialize name, model, opts
      @name = name
      @model = model
      @type = opts[:type]
      @desc = opts[:desc]
      @display_name = opts[:display_name]
      @options = opts[:options]
      @hide = opts[:hide]
      @readonly = opts[:readonly]
      @unique = opts[:unique]
      @match = opts[:match]
      @format_hint = opts[:format_hint]
      @loader = opts[:loader]
    end

    def json_template
      {
        name: @name,
        type: @type.nil? ? @type : @type.name,
        attribute_class: self.class.name,
        desc: @desc,
        display_name: display_name,
        options: @options,
        shown: shown?
      }.delete_if {|k,v| v.nil? }
    end

    def json_for record
      record.send @name
    end

    def validate value, &block
      # is it okay to set this?
      if @match
        if !@match.match(value)
          error = "'#{value}' is improperly formatted."
          if @format_hint
            error = "'#{value}' should be like #{@format_hint}"
          end
          yield error
        end
      end
    end

    def read_only?
      @readonly
    end

    def shown?
      !@hide
    end

    def tab_column?
      shown?
    end

    def matches_schema_type?
      schema.has_key?(column_name)
    end

    def schema_ok?
      matches_schema_type?
    end

    def schema_unchanged? 
      schema_ok? && is_type?(schema[column_name][:db_type])
    end

    def needs_column?
      true
    end

    def column_name
      @name
    end

    def is_type? type
      type.to_sym == literal_type
    end

    def display_name
      @display_name || name.to_s.split(/_/).map(&:capitalize).join(' ')
    end

    def entry migration, mode
      entry = [ migration.column_entry(@name, type, mode) ]
      if @unique
        entry.push migration.unique_entry(@name,mode)
      end
      entry
    end

    def literal_type
      if @type == DateTime
        :"timestamp without time zone"
      else
        Magma.instance.db.cast_type_literal(@type)
      end
    end

    private
    def schema
      @model.schema
    end
  end

  class ForeignKeyAttribute < Attribute
    def column_name
      :"#{@name}_id"
    end

    # you can't change types for keys
    def schema_unchanged? 
      true
    end

    def entry migration, mode
      model = Magma.instance.get_model @name
      migration.foreign_key_entry @name, model, mode
    end

    def json_for record
      link = record.send(@name)
      link ? link.identifier : nil
    end
  end

  class ChildAttribute < Attribute
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
  end

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
        { identifier: l.identifier }
      end
    end
  end

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

  class ImageAttribute < Attribute
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
          path: File.basename(document.current_path),
          thumb: document.thumb.url
        }
      else
        nil
      end
    end
  end
end
