class Magma
  class Model < Sequel::Model
    class << self
      Magma::Attribute.type_attributes.each do |attribute|
          define_method attribute.attribute_type do |attribute_name=nil, opts={}|
            @parent = attribute_name if attribute == Magma::ParentAttribute
            attributes[attribute_name] = attribute.new(opts.merge(
              project_name: project_name,
              model_name: model_name,
              attribute_name: attribute_name,
              magma_model: self
          ))
        end
      end

      alias_method :document, :file

      def load_attributes(attributes = [])
        attributes.each do |attribute|
          @parent = attribute.name if attribute.is_a?(Magma::ParentAttribute)
          attribute.magma_model = self
          self.attributes[attribute.name] = attribute

          if !attribute.is_a?(Magma::Link) && attribute.attribute_name != attribute.column_name
            alias_method attribute.attribute_name, attribute.column_name
            alias_method "#{attribute.attribute_name}=", "#{attribute.column_name}="
          end
        end

        # Table models should always have an identifier attribute
        self.attributes[self.identity.name] = self.identity unless self.attributes.key?(self.identity.name)
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
        @attributes ||= base_attributes
      end

      def base_attributes
        {
            created_at: Magma::DateTimeAttribute.new(
                attribute_name: :created_at,
                project_name: project_name,
                model_name: model_name,
                magma_model: self,
                hidden: true
            ),
            updated_at: Magma::DateTimeAttribute.new(
                attribute_name: :updated_at,
                project_name: project_name,
                model_name: model_name,
                magma_model: self,
                hidden: true
            )
        }
      end

      def has_attribute?(name)
        name.respond_to?(:to_sym) && @attributes.has_key?(name.to_sym)
      end

      def identity
        @identity ||= identifier(primary_key, hidden: true, primary_key: true)
      end

      def identity=(identifier_attribute)
        @identity = identifier_attribute
      end

      def has_identifier?
        !identity.primary_key?
      end

      def parent_model_name
        @parent
      end

      def parent_model
        @parent ? Magma.instance.get_model(project_name, parent_model_name) : nil
      end

      # suggests dictionary entries based on
      def dictionary(dictionary_json = {})
        return @dictionary unless dictionary_json[:dictionary_model]
        @dictionary = Magma::Dictionary.new(dictionary_json)
      end

      # json template of this model
      def json_template(attribute_names = nil)
        attribute_names ||= attributes.keys
        {
            name: model_name,
            attributes: Hash[
                attribute_names.map do |name|
                  [name, attributes[name].json_template]
                end
            ],
            identifier: identity.attribute_name.to_sym,
            dictionary: @dictionary && @dictionary.to_hash,
            parent: parent_model_name,
            # Consider adding again if we decide for using version based locking.
            # version: version,
        }.delete_if { |k, v| v.nil? }
      end

      def schema
        @schema ||= Hash[Magma.instance.db.schema(table_name)]
      end

      # This function is too bulky, it needs to be refactored into smaller
      # pieces.
      def multi_update(records:, src_id: identity, dest_id: identity) end

      def update_or_create(*args)
        obj = find_or_create(*args)
        yield obj if block_given?
        obj.save if obj
      end

      def metrics
        constants.map { |c| const_get(c) }.select do |c|
          c.is_a?(Class) && c < Magma::Metric
        end
      end

      def project_model(name)
        :"#{project_name.to_s.camel_case}::#{name.to_s.camel_case}"
      end

      def inherited(magma_model)
        # Only call set_schema for models that are loaded from file. Models that
        # are loaded from the database get created as anonymous Ruby classes,
        # and anonymous classes don't have names.
        if magma_model.name
          set_schema(
              magma_model.project_name,
              magma_model.model_name.to_s.pluralize.to_sym
          )
        end

        super
      end

      # Sets the appropriate postgres schema for the model. There should be a
      # one to one correlation between a model's module/class and a postgres
      # schema/table.
      def set_schema(project_name, table_name)
        set_dataset(Sequel[project_name][table_name])
      end

      def version
        m = Magma.instance.db[:models].where(project_name: project_name.to_s, model_name: model_name.to_s).first
        if m.nil?
          0
        else
          m[:version]
        end
      end
    end

    # record methods

    def model
      self.class
    end

    def identifier
      send model.identity.column_name
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
            [name, model.attributes[att_name].json_for(self)]
          end
      ].update(
          # always ensure some sort of identifier
          model.identity => identifier
      )
    end
  end
end
