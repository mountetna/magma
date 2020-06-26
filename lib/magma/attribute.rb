class Magma
  class Attribute < Sequel::Model
    plugin :single_table_inheritance, :type, model_map: {
      "parent" => "Magma::ParentAttribute",
      "string" => "Magma::StringAttribute",
      "match" => "Magma::MatchAttribute",
      "identifier" => "Magma::IdentifierAttribute",
      "child" => "Magma::ChildAttribute",
      "integer" => "Magma::IntegerAttribute",
      "boolean" => "Magma::BooleanAttribute",
      "date_time" => "Magma::DateTimeAttribute",
      "table" => "Magma::TableAttribute",
      "matrix" => "Magma::MatrixAttribute",
      "collection" => "Magma::CollectionAttribute",
      "file" => "Magma::FileAttribute",
      "link" => "Magma::LinkAttribute"
    }

    set_primary_key [:project_name, :model_name, :attribute_name]
    unrestrict_primary_key

    plugin :dirty
    plugin :auto_validations

    def validate
      super
      validate_validation_json
    end

    def validate_validation_json
      return unless validation
      validation_object
    rescue => e
      errors.add(:validation, "is not properly formatted")
    end

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

    attr_reader :loader

    class << self
      def options
        [:description, :display_name, :hidden, :read_only, :unique, :index, :validation,
:format_hint, :loader, :link_model_name, :restricted]
      end

      def attribute_type
        @attribute_type ||= name.match("Magma::(.*)Attribute")[1].underscore
      end
    end

    def initialize(opts = {})
      # Some Ipi models set the group option but it doesn't seem to be used anywhere
      opts.delete(:group)

      super(opts.except(:magma_model, :loader))
      self.magma_model = opts[:magma_model]
      @loader = opts[:loader]
    end

    def magma_model=(new_magma_model)
      @magma_model = new_magma_model
      after_magma_model_set
    end

    def after_magma_model_set
    end

    def name
      attribute_name.to_sym
    end

    def database_type
      nil
    end

    def missing_column?
      !@magma_model.columns.include?(column_name)
    end

    def validation_object
      Magma::ValidationObject.build(validation&.symbolize_keys)
    end

    def json_template
      {
        name: attribute_name,
        attribute_name: attribute_name,
        model_name: self.is_a?(Magma::Link) ? link_model.model_name : nil,
        link_model_name: self.is_a?(Magma::Link) ? link_model.model_name : nil,
        type: database_type.respond_to?(:name) ? database_type.name : database_type,
        attribute_class: attribute_class_name,
        desc: description,
        display_name: display_name,
        options: validation_object.options,
        match: validation_object.match,
        restricted: restricted,
        format_hint: format_hint,
        read_only: read_only?,
        hidden: hidden?,
        validation: validation_object,
        attribute_type: self.class.attribute_type
      }.delete_if {|k,v| v.nil? }
    end

    def json_for record
      record[ name ]
    end

    def txt_for(record)
      json_for record
    end

    def update_record(record, new_value)
      record.set({name=> new_value})

      if database_type == DateTime
        return DateTime.parse(new_value)
      elsif database_type == Float
        return new_value.to_f
      elsif database_type == Integer
        return new_value.to_i
      else
        return new_value
      end
    end

    def read_only?
      read_only
    end

    def shown?
      !hidden
    end

    def hidden?
      hidden
    end

    def column_name
      attribute_name.to_sym
    end

    def display_name
      super || (attribute_name && attribute_name.split(/_/).map(&:capitalize).join(' '))
    end

    def update_link(record, link)
    end

    def entry
      if self.class.const_defined?(:Entry)
        self.class.const_get(:Entry)
      else
        Magma::BaseAttributeEntry
      end
    end

    private

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

    class Entry < Magma::BaseAttributeEntry
      def entry(value)
        [ @attribute.name, value ]
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

