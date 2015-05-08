class Magma
  Model = Class.new(Sequel::Model)
  class Model
    class Attribute
      attr_reader :name, :type, :desc
      def initialize name, model, opts
        @name = name
        @model = model
        @type = opts[:type]
        @desc = opts[:desc]
        @unique = opts[:unique]
      end

      def schema_ok?
        schema = Hash[Magma.instance.db.schema @model.table_name]
        return true if schema.has_key?(@name) && is_type?(schema[@name].db_type)
      end

      def is_type? type
        true
      end

      def add_entry
        entry = [ "add_column :#{@name}, #{@type.name}" ]
        if @unique
          entry.push "add_unique_constraint :#{@name}"
        end
        entry
      end

      def display_name
        @display_name || name.to_s.split(/_/).map(&:capitalize).join(' ')
      end

      def new_entry
        entry = [ "#{@type.name} :#{@name}" ]
        if @unique
          entry.push "unique :#{@name}"
        end
        entry
      end
    end
    class << self
      attr_reader :identity
      def attributes
        @attributes ||= {}
      end

      def attribute name, opts
        attributes[name] = Magma::Model::Attribute.new(name, self, opts)
      end

      def has_attribute? name
        @attributes.has_key? name
      end

      def parent name, opts
        many_to_one name
        attribute "#{name}_id".to_sym, opts
      end

      def child name, opts
        one_to_one name
      end

      def collection name, opts
        one_to_many name
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
          att.new_entry
        end.flatten
      end
      
      def suggest_table_update mig
        mig.change "alter_table(:#{table_name})", suggest_missing_attributes
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
