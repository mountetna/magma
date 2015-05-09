class Magma
  Model = Class.new(Sequel::Model)
  class Model
    class Attribute
      DISPLAY_ONLY = [ :child, :collection ]
      attr_reader :name, :type, :desc
      def initialize name, model, opts
        @name = name
        @model = model
        @type = opts[:type]
        @desc = opts[:desc]
        @display_name = opts[:display_name]
        @unique = opts[:unique]
      end

      def schema_ok?
        display_only? || generic_schema_ok? || foreign_key_ok?
      end

      def generic_schema_ok?
        @type.is_a?(Class) && (schema.has_key?(@name) && is_type?(schema[@name][:db_type]))
      end

      def foreign_key_ok?
        name = "#{@name}_id".to_sym
        @type == :foreign_key && (schema.has_key?(name) && is_type?(schema[name][:db_type]))
      end

      def display_only?
        DISPLAY_ONLY.include? @type
      end

      def is_type? type
        true
      end

      def add_entry
        if @type.is_a? Class
          add_generic_entry
        elsif @type == :foreign_key
          add_key_entry
        end
      end

      def display_name
        @display_name || name.to_s.split(/_/).map(&:capitalize).join(' ')
      end

      def new_entry
        if @type.is_a? Class
          new_generic_entry
        elsif @type == :foreign_key
          new_key_entry
        end
      end

      private
      def new_generic_entry
        entry = [ "#{@type.name} :#{@name}" ]
        if @unique
          entry.push "unique :#{@name}"
        end
        entry
      end

      def add_generic_entry
        entry = [ "add_column :#{@name}, #{@type.name}" ]
        if @unique
          entry.push "add_unique_constraint :#{@name}"
        end
        entry
      end

      def new_key_entry
        model = Magma.instance.get_model @name
        "foreign_key :#{@name}_id, :#{model.table_name}"
      end

      def add_key_entry
        model = Magma.instance.get_model @name
        "add_foreign_key :#{@name}_id, :#{model.table_name}"
      end

      def schema
        @schema ||= Hash[Magma.instance.db.schema @model.table_name]
      end
    end
    class << self
      attr_reader :identity
      def attributes
        @attributes ||= {}
      end

      def attribute name, opts = {}
        attributes[name] = Magma::Model::Attribute.new(name, self, opts)
      end

      def has_attribute? name
        @attributes.has_key? name
      end

      def parent name, opts = {}
        many_to_one name
        attribute name, opts.merge(type: :foreign_key)
      end

      def child name, opts = {}
        one_to_one name
        attribute name, opts.merge(type: :child)
      end

      def collection name, opts = {}
        one_to_many name
        attribute name, opts.merge(type: :collection)
      end

      def identifier name, opts
        attribute name, opts.merge(unique: true)
        @identity = name
      end

      def validate
        raise "Missing table for #{name}." unless Magma.instance.db.table_exists? table_name
      end

      def suggest_migration mig
        if Magma.instance.db.table_exists? table_name
          suggest_table_update mig
        else
          suggest_table_creation mig
        end
      end

      private
      def suggest_table_creation mig
        mig.change "create_table(:#{table_name})", [ "primary_key :id" ] + suggest_new_attributes
      end

      def suggest_new_attributes
        attributes.map do |name,att|
          next if att.display_only?
          att.new_entry
        end.compact.flatten
      end
      
      def suggest_table_update mig
        missing = suggest_missing_attributes
        mig.change "alter_table(:#{table_name})", missing unless missing.empty?
      end

      def suggest_missing_attributes
        attributes.map do |name,att|
          next if att.schema_ok?
          att.add_entry
        end.compact.flatten
      end
    end
  end
end
