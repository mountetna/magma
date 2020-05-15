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
      :loader,
      :readonly,
      :restricted,
      :unique,
      :validation
    ]

    attr_reader :name, :loader, :validation, :format_hint, :unique, :index, :restricted, :link_model_name

    class << self
      def options
        [:description, :display_name, :hidden, :readonly, :unique, :index, :validation,
:format_hint, :loader, :link_model_name, :restricted, :desc ]
      end

      def set_attribute(name, model, options, attribute_class)
        attribute_class.new(name, model, options)
      end
    end

    def initialize(name, model, opts)
      @name = name
      @model = model
      set_options(opts)
    end

    def database_type
      nil
    end

    def validation_object
      @validation_object ||= Magma::ValidationObject.build(@validation&.symbolize_keys)
    end

    def json_template
      {
        name: @name,
        model_name: self.is_a?(Magma::Link) ? link_model.model_name : nil,
        type: database_type.respond_to?(:name) ? database_type.name : database_type,
        attribute_class: attribute_class_name,
        desc: description,
        display_name: display_name,
        options: validation_object.options,
        match: validation_object.match,
        restricted: @restricted,
        format_hint: @format_hint,
        read_only: read_only?,
        shown: shown?
      }.delete_if {|k,v| v.nil? }
    end

    def json_for record
      record[ @name ]
    end

    def txt_for(record)
      json_for record
    end

    def update(record, new_value)
      record.set({@name=> new_value})

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
      @readonly
    end

    def shown?
      !@hidden
    end

    def column_name
      @name
    end


    def display_name
      @display_name ||= name.to_s.split(/_/).map(&:capitalize).join(' ')
    end

    def description
      @description || @desc
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

