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

      def order(*columns)
        @order = columns
        set_dataset(dataset.order(*@order))
      end

      def attribute(attr_name, opts = {})

        klass = opts.delete(:attribute_class) || Magma::Attribute
        attributes[attr_name] = klass.new(attr_name, self, opts)
      end

      def has_attribute?(name)
        name.respond_to?(:to_sym) && @attributes.has_key?(name.to_sym)
      end

      def parent name=nil, opts = {}
        if name
          @parent = name
          many_to_one name
          attribute name, opts.merge(attribute_class: Magma::ForeignKeyAttribute)
        end
        @parent
      end

      def child(name, opts = {})
        one_to_one(name)
        attribute(name, opts.merge(attribute_class: Magma::ChildAttribute))
      end

      def link(name, opts = {})
        full_model_name = resolve_namespace(opts[:link_model] || name)
        many_to_one(name, class: full_model_name)
        attribute(name, opts.merge(attribute_class: Magma::ForeignKeyAttribute))
      end

      def file name, opts = {}
        mount_uploader name, Magma::FileUploader
        attribute name, opts.merge(attribute_class: Magma::FileAttribute)
      end
      alias_method :document, :file

      def image name, opts = {}
        mount_uploader name, Magma::ImageUploader
        attribute name, opts.merge(attribute_class: Magma::ImageAttribute)
      end

      def collection(name, opts = {})
        one_to_many(name, class: resolve_namespace(name), primary_key: :id)
        attribute(name, opts.merge(attribute_class: Magma::CollectionAttribute))
      end

      def table(name, opts = {})
        one_to_many(name, class: resolve_namespace(name), primary_key: :id)
        attribute(name, opts.merge(attribute_class: Magma::TableAttribute))
      end

      def identifier(name, opts)
        attribute(name, opts.merge(unique: true))
        @identity = name

        # Default ordering is by identifier.
        order(name) unless @order
      end

      # Set and/or return the validator for this model.
      def validator(class_name = nil)
        if(class_name == nil && @validator != nil)
          return @validator
        else
          if(class_name != nil)

            # Get the name space for the validator and append it's class name to
            # it to generate a 'new' for return.
            class_name = "#{self.name.split(/::/)[0]}::#{class_name.to_s}"
            if Kernel.const_defined?(class_name)
              @validator = Kernel.const_get(class_name)
            end

            return @validator
          end
        end
        return nil
      end

      # REDUNDANT FUNCTIONS!

      def project_name
        name.split('::').first.snake_case.to_sym
      end

      def model_name
        name.split('::').last.snake_case.to_sym
      end

      def has_table?
        Magma.instance.db.table_exists?(table_name)
      end

      def migration
        Magma::Migration.create(self)
      end

      def json_template(attribute_names = nil)
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

      def schema
        @schema ||= Hash[Magma.instance.db.schema(table_name)]
      end

      # This function is too bulky, it needs to be refactored into smaller
      # pieces.
      def multi_update(records:, src_id: identity, dest_id: identity)

        return if records.empty?

        # Get the name of the columns to update for the record.
        update_columns = records.first.keys - [src_id]
        return if update_columns.empty?

        # Get a handle to the DB.
        db = Magma.instance.db

        db.transaction do

          temp_table_name = :"bulk_update_#{project_name}_#{model_name.to_s.plural}"

          orig_table_name = "#{project_name}.#{model_name.to_s.plural}".to_sym

          # Create a temporary database and drop when done, also copy the source
          # table structure (by Sequel model) onto the temp table.
          temp_table_query = <<-EOT
            CREATE TEMP TABLE #{temp_table_name}
            ON COMMIT DROP
            AS SELECT * FROM #{orig_table_name} WHERE 1=0;
          EOT

          puts temp_table_query
          db.run(temp_table_query)

          # In the event of foreign keys we create another column in our
          # temporary table for matching later.
          temp_table_query = <<-EOT
            ALTER TABLE #{temp_table_name}
            ADD COLUMN #{src_id} integer;
          EOT

          unless columns.include?(src_id)
            puts temp_table_query
            db.run(temp_table_query)
          end

          # Insert the records into the temporary DB.
          db[temp_table_name].multi_insert(records)

          # Generate the column name mapping from the temporary database to the 
          # permanent one.
          column_alias = update_columns.map do |column| 
            "#{column}=src.#{column}"
          end.join(', ')

          # Move the data from the temporary database into the permanent one.
          # This should also destroy the temporary database.
          temp_table_query = <<-EOT
            UPDATE #{orig_table_name} AS dest
            SET #{column_alias}
            FROM #{temp_table_name} AS src
            WHERE dest.#{dest_id} = src.#{src_id};
          EOT

          db.run(temp_table_query)
        end
      end

      def update_or_create(*args)
        obj = find_or_create(*args)
        yield obj if block_given?
        obj.save if obj
      end

      def metrics
        constants.map{|c| const_get(c)}.select do |c|
          c.is_a?(Class) && c < Magma::Metric
        end
      end

      # Extract the full module name and prepend it to the incoming class name
      # so we can get the correct Module/Class reference. This one is to 
      # correctly format the Ruby models so they may reference eachother.
      def resolve_namespace(name)
        :"#{self.name.split(/::/).first}::#{name.to_s.camel_case}"
      end

      # Takes the module/class namespace and turns it into a postgres
      # schema/table string. This one is to establish the Sequel Model to 
      # Postgres DB connection.
      def namespaced_table_name(subclass)
        project_name, table_name = subclass.name.split(/::/).map(&:snake_case)
        table_name = table_name.plural
        Sequel[project_name.to_sym][table_name.to_sym]
      end

      def inherited(subclass)
        # Sets the appropriate postgres schema for the model. There should be a 
        # one to one correlation between a model's module/class and a postgres
        # schema/table.
        set_dataset(namespaced_table_name(subclass))
        super
        subclass.attribute(:created_at, type: DateTime, hide: true)
        subclass.attribute(:updated_at, type: DateTime, hide: true)
      end
    end

    def identifier
      send model.identity
    end

    # Run a loader on a hook from carrier_wave.
    def run_loaders(att, file)
      if model.attributes[att].loader
        send(model.attributes[att].loader)
      end
    end

    def model
      self.class
    end

    def json_document(attribute_names = nil)
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

    def json_for(att_name)
      model.attributes[att_name].json_for(self)
    end

    def txt_for(att_name)
      model.attributes[att_name].txt_for(self)
    end
  end
end
