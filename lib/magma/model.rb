Sequel::Model.plugin :timestamps, update_on_create: true
Sequel::Model.require_valid_table = false
Sequel.extension :inflector

class Magma
  Model = Class.new(Sequel::Model)
   
  class Model
    ATTRIBUTES_TYPES = [
      :string, :integer, :boolean, :date_time, :float, :file, :image, 
      :collection, :table, :match, :matrix, :child, :identifier, :parent, :link
    ].freeze
    class << self
      ATTRIBUTES_TYPES.each do |method_name|
        define_method method_name do |attribute_name=nil, opts={}|
          klass = "Magma::#{method_name.to_s.capitalize}_attribute".camelcase.constantize
          @parent = attribute_name if method_name == :parent
          attributes[attribute_name] = klass.new(attribute_name, self, opts)
        end
      end

      alias_method :document, :file

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
          magma_model.date_time(timestamp, {hide: true})
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
