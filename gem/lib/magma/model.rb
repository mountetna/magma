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

      def order *columns
        @order = columns
        set_dataset dataset.order(*@order)
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

        # default ordering is by identifier
        order(name) unless @order
      end

      def validate
        raise "Missing table for #{name}." unless Magma.instance.db.table_exists? table_name
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

      def multi_update records
        return if records.empty?
        update_columns = records.first.keys
        return if update_columns.empty?
        db = Magma.instance.db
        db.transaction do
          update_table_name = :"bulk_update_#{table_name}"
          create_bulk_update = "CREATE TABLE #{update_table_name} AS SELECT * FROM #{table_name} WHERE 1=0;"
          update_main_table = <<-EOT
                  UPDATE #{table_name} AS dest
                  SET #{update_columns.map do |column| "#{column}=src.#{column}" end.join(", ")}
                  FROM #{update_table_name} AS src
                  WHERE dest.#{identity} = src.#{identity};
          EOT
          remove_bulk_update = "DROP TABLE #{update_table_name};"

          db.run(create_bulk_update)
          db[update_table_name].multi_insert records
          db.run(update_main_table)
          db.run(remove_bulk_update)
        end
      end

      def update_or_create *args
        obj = find_or_create(*args)
        yield obj if block_given?
        obj.save if obj
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

    def json_document
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
