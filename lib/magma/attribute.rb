class Magma
  class Attribute
    DISPLAY_ONLY = [:child, :collection]
    EDITABLE_OPTIONS = [:description, :display_name, :format_hint]

    attr_reader :name, :loader, :match, :format_hint, :unique, :index, :restricted

    class << self
      def options
        [:description, :display_name, :hide, :readonly, :unique, :index, :match,
:format_hint, :loader, :link_model, :restricted, :desc ]
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

    def _type
    end

    def json_template
      {
        name: @name,
        model_name: self.is_a?(Magma::Link) ? link_model.model_name : nil,
        type: _type.nil? ? nil : _type.respond_to?(:name) ? _type.name : _type,
        attribute_class: self.class.name,
        desc: description,
        display_name: display_name,
        options: @match.is_a?(Array) ? @match : nil,
        match: @match.is_a?(Regexp) ? @match.source : nil,
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

      if _type == DateTime
        return DateTime.parse(new_value)
      elsif _type == Float
        return new_value.to_f
      elsif _type == Integer
        return new_value.to_i
      else
        return new_value
      end
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

      Magma.instance.db[:attributes].
        insert_conflict(
          target: [:project_name, :model_name, :attribute_name],
          update: { "#{opt}": new_value, updated_at: Time.now }
        ).insert(
          project_name: @model.project_name.to_s,
          model_name: @model.model_name.to_s,
          attribute_name: name.to_s,
          created_at: Time.now,
          updated_at: Time.now,
          "#{opt}": new_value
        )

      instance_variable_set("@#{opt}", new_value)
    end

    private

    def set_options(opts)
      opts = opts.merge(persisted_attribute_options)

      opts.each do |opt,value|
        if self.class.options.include?(opt)
          instance_variable_set("@#{opt}", value)
        end
      end
    end

    def persisted_attribute_options
      persisted_attribute = Magma.instance.db[:attributes].first(
        project_name: @model.project_name.to_s,
        model_name: @model.model_name.to_s,
        attribute_name: name.to_s
      )

      persisted_attribute&.slice(*EDITABLE_OPTIONS) || {}
    end

    class Validation < Magma::Validation::Attribute::BaseAttributeValidation
      def validate(value)
        case match
        when Regexp
          yield format_error(value) if !match.match(value)
        when Array
          if !match.map(&:to_s).include?(value)
            yield "On #{@attribute.name}, '#{value}' should be one of #{match.join(", ")}."
          end
        end
      end

      private

      # memoize match to reuse across validations
      def match
        @match ||= @attribute.match.is_a?(Proc) ? @attribute.match.call : @attribute.match
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

