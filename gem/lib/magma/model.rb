class Magma
  Model = Class.new(Sequel::Model)
  class Model
    plugin :timestamps, update_on_create: true
    
    class << self
      attr_reader :identity
      def attributes
        @attributes ||= {}
      end

      def display_attributes
        attributes.select do |name|
          attributes[name].shown?
        end
      end

      def attribute name, opts = {}
        klass = opts.delete(:attribute_class) || Magma::Attribute
        attributes[name] = klass.new(name, self, opts)
      end

      def has_attribute? name
        @attributes.has_key? name
      end

      def parent name, opts = {}
        many_to_one name
        attribute name, opts.merge(attribute_class: Magma::ForeignKeyAttribute)
      end

      def child name, opts = {}
        one_to_one name
        attribute name, opts.merge(attribute_class: Magma::ChildAttribute)
      end

      def document name, opts = {}
        mount_uploader name, Magma::Document
        attribute name, opts.merge(attribute_class: Magma::DocumentAttribute)
      end

      def image name, opts = {}
        mount_uploader name, Magma::Image
        attribute name, opts.merge(attribute_class: Magma::ImageAttribute)
      end

      def collection name, opts = {}
        one_to_many name, primary_key: :id
        attribute name, opts.merge(attribute_class: Magma::CollectionAttribute)
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

      def json_template
        # Return a json template of this thing.
        {
          name: name,
          attributes: attributes.map do |name,att|
            { name => att.json_template }
          end.reduce(:merge),
          identifier: identity
        }
      end

      def schema
        @schema ||= Hash[Magma.instance.db.schema table_name]
      end

      private
      def suggest_table_creation mig
        mig.change "create_table(:#{table_name})", [ "primary_key :id" ] + suggest_new_attributes
      end

      def suggest_new_attributes
        attributes.map do |name,att|
          next unless att.needs_column?
          att.new_entry
        end.compact.flatten
      end
      
      def suggest_table_update mig
        missing = suggest_missing_attributes
        mig.change "alter_table(:#{table_name})", missing unless missing.empty?

        removed = suggest_removed_attributes
        mig.change "alter_table(:#{table_name})", removed unless removed.empty?
      end

      def suggest_missing_attributes
        attributes.map do |name,att|
          next if att.schema_ok?
          att.add_entry
        end.compact.flatten
      end

      def suggest_removed_attributes
        schema.map do |name, db_opts|
          next if attributes[name]
          next if attributes[ name.to_s.sub(/_id$/,'').to_sym ]
          next if db_opts[:primary_key]
          "drop_column :#{name}"
        end.compact.flatten
      end
    end

    def self.inherited(subclass)
      super
      subclass.attribute :created_at, type: DateTime, hide: true
      subclass.attribute :updated_at, type: DateTime, hide: true
    end

    def identifier
      send self.class.identity
    end

    def run_loaders att, file
      if self.class.attributes[att].loader
        send self.class.attributes[att].loader, file
      end
      # run a loader on a hook from carrier_wave
    end

    def json_template
      # A JSON version of this record. Each attribute reports in a fashion that is useful
      hash = {
        id: id
      }
      self.class.attributes.each do |name,att|
        hash.update name => att.json_for(self)
      end
      hash
    end
  end
end
