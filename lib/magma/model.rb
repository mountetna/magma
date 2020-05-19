Sequel::Model.plugin :timestamps, update_on_create: true
Sequel::Model.require_valid_table = false
Sequel.extension :inflector

class Magma
  Model = Class.new(Sequel::Model)
   
  class Model
    class << self
      Magma::Attribute.descendants.
        reject { |attribute| attribute == Magma::ForeignKeyAttribute }.
        each do |attribute|
          define_method attribute.attribute_type do |attribute_name=nil, opts={}|
            @parent = attribute_name if attribute == Magma::ParentAttribute
            attributes[attribute_name] = attribute.new(attribute_name, self, opts)
          end
        end

      alias_method :document, :file

      def load_attributes(attributes = {})
        attributes.each do |attribute|
          send(
            attribute[:type],
            attribute[:attribute_name].to_sym,
            attribute.slice(*Magma::Attribute::EDITABLE_OPTIONS)
          )
        end
      end

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

      def order(*columns)
        @order = columns
        set_dataset dataset.order(*@order)
      end

      # attributes point to pieces of data, including
      # records and collections of records
      def attributes
        @attributes ||= {}
      end

      def has_attribute?(name)
        name.respond_to?(:to_sym) && @attributes.has_key?(name.to_sym)
      end

      def identity
        @identity || primary_key
      end

      def identity=(identity)
        @identity = (identity)
      end

      def has_identifier?
        @identity
      end

      def parent_model_name
        @parent
      end

      def restricted(opts= {})
        attributes[:restricted] = Magma::BooleanAttribute.new(:restricted, self, opts)
      end

      # suggests dictionary entries based on
      def dictionary(dict_model=nil, attributes={})
        return @dictionary unless dict_model
        @dictionary = Magma::Dictionary.new(self, dict_model, attributes)
      end

      # json template of this model
      def json_template(attribute_names = nil)
        attribute_names ||= attributes.keys
        {
          name: model_name,
          attributes: Hash[
            attribute_names.map do |name|
              [ name, attributes[name].json_template ]
            end
          ],
          identifier: identity,
          dictionary: @dictionary && @dictionary.to_hash,
          parent: parent_model_name
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

          temp_table_name = :"bulk_update_#{project_name}_#{table_name.column}"

          orig_table_name = "#{project_name}.#{table_name.column}".to_sym

          # Create a temporary database and drop when done, also copy the source
          # table structure (by Sequel model) onto the temp table.
          temp_table_query = <<-EOT
            CREATE TEMP TABLE #{temp_table_name}
            ON COMMIT DROP
            AS SELECT * FROM #{orig_table_name} WHERE 1=0;
          EOT

          db.run(temp_table_query)

          # In the event of foreign keys we create another column in our
          # temporary table for matching later.
          temp_table_query = <<-EOT
            ALTER TABLE #{temp_table_name}
            ADD COLUMN #{src_id} integer;
          EOT

          unless columns.include?(src_id)
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

      def project_model(name)
        :"#{project_name.to_s.camel_case}::#{name.to_s.camel_case}"
      end

      def inherited(magma_model)
        # Sets the appropriate postgres schema for the model. There should be a 
        # one to one correlation between a model's module/class and a postgres
        # schema/table.
        set_dataset(
          Sequel[
            magma_model.project_name
          ][
            magma_model.model_name.to_s.pluralize.to_sym
          ]
        )

        super
        %i(created_at updated_at).each do |timestamp|
          magma_model.date_time(timestamp, {hidden: true})
        end
      end
    end

    # record methods

    def model
      self.class
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

    def json_document(attribute_names = nil)
      # A JSON version of this record (actually a hash). Each attribute
      # reports in its own fashion
      Hash[
        (attribute_names || model.attributes.keys).map do |name|
          [ name, model.attributes[att_name].json_for(self) ]
        end
      ].update(
        # always ensure some sort of identifier
        model.identity => identifier
      )
    end
  end
end
