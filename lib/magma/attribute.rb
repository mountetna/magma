class Magma
  class Attribute
    DISPLAY_ONLY = [:child, :collection]

    EDITABLE_OPTIONS = [
      :description,
      :display_name,
      :format_hint,
      :hidden,
      :index,
      :link_model_name,
      :read_only,
      :restricted,
      :unique,
      :validation
    ]

    attr_reader :name, :loader, :validation, :format_hint, :unique, :index, :restricted, :link_model_name, :description, :hidden

    class << self
      def options
        [:description, :display_name, :hidden, :read_only, :unique, :index, :validation,
:format_hint, :loader, :link_model_name, :restricted]
      end

      def set_attribute(name, model, options, attribute_class)
        attribute_class.new(name, model, options)
      end

      def attribute_type
        @attribute_type ||= name.match("Magma::(.*)Attribute")[1].underscore
      end
    end

    def initialize(name, model, opts)
      @name = name
      @model = model
      set_options(opts)
    end

    def read_only?
      @readonly
    end

    def shown?
      !@hide
    end

    def column_name
      @name
    end

    def display_name
      @display_name || name.to_s.split(/_/).map(&:capitalize).join(' ')
    end
    
    def database_type
      nil
    end

    def missing_column?
      !@model.columns.include?(column_name)
    end

    def validation_object
      @validation_object ||= Magma::ValidationObject.build(@validation&.symbolize_keys)
    end

    def json_template
      {
        name: @name,
        attribute_name: @name,
        model_name: self.is_a?(Magma::Link) ? link_model.model_name : nil,
        link_model_name: self.is_a?(Magma::Link) ? link_model.model_name : nil,
        type: database_type.respond_to?(:name) ? database_type.name : database_type,
        attribute_class: attribute_class_name,
        desc: description,
        display_name: display_name,
        options: validation_object.options,
        match: validation_object.match,
        restricted: @restricted,
        format_hint: @format_hint,
        read_only: read_only?,
        hidden: hidden?,
        validation: validation_object,
        attribute_type: self.class.attribute_type
      }.delete_if {|k,v| v.nil? }
    end

    def query_to_payload(value)
      value
    end

    def query_to_tsv(value)
      query_to_payload(value)
    end

    def revision_to_loader(record_name, new_value)
      [
        @name,
        @type == DateTime ?
          DateTime.parse(new_value) :
        @type == Float ?
          new_value.to_f :
        @type == Integer ?
          new_value.to_i :
          new_value
      ]
    end

    def revision_to_links(record_name, value)
    end

    def revision_to_payload(record_name, value)
      revision_to_loader(record_name, value)
    end

    def entry(value, loader)
      [ name, value ]
    end

    def update_option(opt, new_value)
      opt = opt.to_sym
      return unless EDITABLE_OPTIONS.include?(opt)

      database_value = new_value.is_a?(Hash) ? Sequel.pg_json_wrap(new_value) : new_value

      Magma.instance.db[:attributes].
        insert_conflict(
          target: [:project_name, :model_name, :attribute_name],
          update: { "#{opt}": database_value, updated_at: Time.now }
        ).insert(
          project_name: @model.project_name.to_s,
          model_name: @model.model_name.to_s,
          attribute_name: name.to_s,
          type: self.class.attribute_type,
          created_at: Time.now,
          updated_at: Time.now,
          "#{opt}": database_value
        )

      instance_variable_set("@#{opt}", new_value)
      @validation_object = nil if opt == :validation
    end

    private

    def set_options(opts)
      opts.each do |opt,value|
        if self.class.options.include?(opt)
          instance_variable_set("@#{opt}", value)
        end
      end
    end

    MAGMA_ATTRIBUTES = [
      "Magma::BooleanAttribute",
      "Magma::DateTimeAttribute",
      "Magma::FloatAttribute",
      "Magma::IdentifierAttribute",
      "Magma::IntegerAttribute",
      "Magma::StringAttribute"
    ]

    FOREIGN_KEY_ATTRIBUTES = [
      "Magma::LinkAttribute",
      "Magma::ParentAttribute"
    ]

    def attribute_class_name
      case self.class.name
      when *MAGMA_ATTRIBUTES
        "Magma::Attribute"
      when *FOREIGN_KEY_ATTRIBUTES
        "Magma::ForeignKeyAttribute"
      else
        self.class.name
      end
    end
  end
end

require_relative 'attributes/link'
require_relative 'attributes/child'
require_relative 'attributes/collection'
require_relative 'attributes/file'
require_relative 'attributes/foreign_key'
require_relative 'attributes/match'
require_relative 'attributes/image'
require_relative 'attributes/table'
require_relative 'attributes/matrix'
require_relative 'attributes/string_attribute'
require_relative 'attributes/integer_attribute'
require_relative 'attributes/boolean_attribute'
require_relative 'attributes/date_time_attribute'
require_relative 'attributes/float_attribute'
require_relative 'attributes/identifier_attribute'
require_relative 'attributes/parent_attribute'
require_relative 'attributes/link_attribute'

