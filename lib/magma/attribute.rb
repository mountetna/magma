class Magma
  class Attribute
    DISPLAY_ONLY = [:child, :collection]
    attr_reader :name, :type, :desc, :loader, :match, :format_hint, :unique, :index


    class << self
      def options
        [:type, :desc, :display_name, :hide, :readonly, :unique, :index, :match,
:format_hint, :loader, :link_model]
      end
    end

    def initialize(name, model, opts)
      @name = name
      @model = model
      set_options(opts)
    end

    def json_template
      {
        name: @name,
        model_name: self.is_a?(Magma::Link) ? link_model.model_name : nil,
        type: @type.nil? ? nil : @type.respond_to?(:name) ? @type.name : @type,
        attribute_class: self.class.name,
        desc: @desc,
        display_name: display_name,
        options: @match.is_a?(Array) ? @match : nil,
        match: @match.is_a?(Regexp) ? @match.source : nil,
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

    def set_options(opts)
      opts.each do |opt,value|
        if self.class.options.include?(opt)
          instance_variable_set("@#{opt}", value)
        end
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
