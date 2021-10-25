class Magma
  class Attribute < Sequel::Model
    plugin :single_table_inheritance, :type,
      model_map: Proc.new { |type| "Magma::#{type.classify}Attribute" },
      key_map: Proc.new { |attribute| attribute.attribute_type }

    set_primary_key [:project_name, :model_name, :column_name]
    unrestrict_primary_key

    plugin :dirty
    plugin :auto_validations

    DISPLAY_ONLY = [:child, :collection]

    EDITABLE_OPTIONS = [
      :description,
      :display_name,
      :format_hint,
      :hidden,
      :attribute_group,
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
        [:description, :display_name, :hidden, :attribute_group, :read_only, :unique, :index, :validation,
:format_hint, :loader, :link_model_name, :restricted]
      end

      def type_attributes
        descendants.reject do |att_class|
          att_class == Magma::ForeignKeyAttribute
        end
      end

      def attribute_types
        type_attributes.map(&:attribute_type)
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
      self.column_name = initial_column_name unless self.column_name
      @loader = opts[:loader]
    end

    def magma_model=(new_magma_model)
      @magma_model = new_magma_model
      after_magma_model_set
    end

    def name
      attribute_name.to_sym
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

    def primary_key?
      !!@primary_key
    end

    def display_name
      super || (attribute_name && attribute_name.split(/_/).map(&:capitalize).join(' '))
    end

    def database_type
      nil
    end

    def missing_column?
      !@magma_model.columns.include?(column_name.to_sym)
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
        description: description,
        desc: description,
        display_name: display_name,
        attribute_group: attribute_group,
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

    def query_to_payload(value)
      value
    end

    def query_to_tsv(value)
      query_to_payload(value)
    end

    def revision_to_loader(record_name, new_value)
      [ name, new_value ]
    end

    def revision_to_links(record_name, value)
    end

    def revision_to_payload(record_name, value, loader)
      revision_to_loader(record_name, value)
    end

    def entry(value, loader)
      [ column_name.to_sym, value ]
    end

    def load_hook(loader, record_name, value, bulk_load)
    end

    def patch_load_hook(loader, record_name, record)
    end

    def bulk_load_hook(loader, bulk_load)
    end

    def self.type_bulk_load_hook(loader, project_name, bulk_type_attributes)
    end

    private

    def after_magma_model_set
    end

    def initial_column_name
      attribute_name
    end

    MAGMA_ATTRIBUTES = [
      "Magma::BooleanAttribute",
      "Magma::DateTimeAttribute",
      "Magma::FloatAttribute",
      "Magma::IdentifierAttribute",
      "Magma::IntegerAttribute",
      "Magma::StringAttribute",
      "Magma::ShiftedDateTimeAttribute"
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

    # Use Sequel::Model validations to validate values before they get inserted
    # into the database. Call super first to execute validations provided by the
    # auto_validations plugin.
    def validate
      super
      validate_validation_json
      validate_attribute_name_format
      validate_type
      validate_attribute_name_unique
      validate_attribute_group_format
    end

    def validate_validation_json
      return unless validation
      validation_object
    rescue => e
      Magma.instance.logger.log_error(e)
      errors.add(:validation, "is not properly formatted")
    end

    SNAKE_CASE_WORD=/\A[a-z][a-z0-9]*(_[a-z0-9]+)*\Z/

    def validate_attribute_name_format
      return if attribute_name =~ SNAKE_CASE_WORD
      errors.add(:attribute_name, "must be snake_case with no spaces")
    end

    def validate_attribute_group_format
      return if !attribute_group || attribute_group =~ SNAKE_CASE_WORD
      errors.add(:attribute_group, "must be snake_case with no spaces")
    end

    def validate_type
      return if Magma.const_defined?("#{type.classify}Attribute")
      errors.add(:type, "is not a supported type")
    end

    def validate_attribute_name_unique
      return unless modified?(:attribute_name)
      return unless @magma_model.has_attribute?(attribute_name)
      errors.add(:attribute_name, "already exists on the model")
    end
  end
end

require_relative 'attributes/link'
require_relative 'attributes/child'
require_relative 'attributes/collection'
require_relative 'attributes/file_attribute'
require_relative 'attributes/file_collection_attribute'
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
require_relative 'attributes/shifted_date_time_attribute'

