Sequel::Model.plugin :timestamps, update_on_create: true

class Magma
  Model = Class.new(Sequel::Model)
  class Model
    class << self
      def attributes
        @attributes ||= {}
      end

      def identity
        @identity || primary_key
      end

      def has_identifier?
        @identity
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
        name.respond_to?(:to_sym) && @attributes.has_key?(name.to_sym)
      end

      def parent name, opts = {}
        @parent = name
        many_to_one name
        attribute name, opts.merge(attribute_class: Magma::ForeignKeyAttribute)
      end

      def link name, opts = {}
        many_to_one name, class: (opts[:link_model] || name).to_s.camel_case.to_sym
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

      def table name, opts = {}
        one_to_many name, primary_key: :id
        attribute name, opts.merge(attribute_class: Magma::TableAttribute)
      end

      def identifier name, opts
        attribute name, opts.merge(unique: true)
        @identity = name

        # default ordering is by identifier
        order(name) unless @order
      end

      def model_name
        name.snake_case.to_sym
      end

      def has_table?
        Magma.instance.db.table_exists? table_name
      end

      def migration
        Magma::Migration.create(self)
      end

      def json_template attribute_names=nil
        # Return a json template of this thing.
        attribute_names ||= attributes.keys
        {
          name: model_name, 
          attributes: Hash[
            attribute_names.map do |name|
              [ name, attributes[name].json_template ]
            end
          ],
          identifier: identity,
          parent: @parent
        }.delete_if {|k,v| v.nil? }
      end

      def assoc_models att_names=nil
        att_names ||= attributes.keys
        att_names.map do |name|
          att = attributes[name]
          next unless att && att.is_a?(Magma::TableAttribute)
          att.link_model
        end.flatten.compact
      end

      def schema
        @schema ||= Hash[Magma.instance.db.schema table_name]
      end

      def multi_update records:, src_id: identity, dest_id: identity
        return if records.empty?
        update_columns = records.first.keys - [ src_id ]
        return if update_columns.empty?
        db = Magma.instance.db
        db.transaction do
          update_table_name = :"bulk_update_#{table_name}"
          create_bulk_update = "CREATE TEMP TABLE #{update_table_name} ON COMMIT DROP AS SELECT * FROM #{table_name} WHERE 1=0;"
          add_src_id_column = "ALTER TABLE #{update_table_name} ADD COLUMN #{src_id} integer;"
          update_main_table = <<-EOT
                  UPDATE #{table_name} AS dest
                  SET #{update_columns.map do |column| "#{column}=src.#{column}" end.join(", ")}
                  FROM #{update_table_name} AS src
                  WHERE dest.#{dest_id} = src.#{src_id};
          EOT

          puts create_bulk_update
          db.run(create_bulk_update)
          unless columns.include?(src_id)
            puts add_src_id_column
            db.run(add_src_id_column)
          end
          db[update_table_name].multi_insert records
          puts update_main_table
          db.run(update_main_table)
        end
      end

      def update_or_create *args
        obj = find_or_create(*args)
        yield obj if block_given?
        obj.save if obj
      end

      def metrics
        constants.map{|c| const_get(c)}.select do |c|
          c.is_a?(Class) && c < Magma::Metric
        end
      end
    end

    def self.inherited(subclass)
      super
      subclass.attribute :created_at, type: DateTime, hide: true
      subclass.attribute :updated_at, type: DateTime, hide: true
    end

    def identifier
      send model.identity
    end

    def run_loaders att, file
      if model.attributes[att].loader
        send model.attributes[att].loader
      end
      # run a loader on a hook from carrier_wave
    end

    def model
      self.class
    end

    def json_document attribute_names=nil
      # A JSON version of this record (actually a hash). Each attribute
      # reports in its own fashion
      Hash[
        (attribute_names || model.attributes.keys).map do |name|
          [ name, json_for(name)  ]
        end
      ].update(
        # always ensure some sort of identifier
        model.identity => identifier
      )
    end

    def json_for att_name
      model.attributes[att_name].json_for(self)
    end

    def txt_for att_name
      model.attributes[att_name].txt_for(self)
    end
  end
end
