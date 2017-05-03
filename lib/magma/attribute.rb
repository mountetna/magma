class Magma
  class Attribute
    def self.options
      [ :type, :desc, :display_name, 
        :hide, :readonly, :unique, :index,
        :match, :format_hint, :loader,
        :link_model
      ]
    end
    DISPLAY_ONLY = [ :child, :collection ]
    attr_reader :name, :type, :desc, :loader
    def initialize name, model, opts
      @name = name
      @model = model

      set_options opts
    end

    def json_template
      {
        name: @name,
        model_name: @link_model || @name,
        type: @type.nil? ? nil : @type.name,
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
      record.send @name
    end

    def txt_for record
      json_for record
    end

    def entry_for value
      [ @name, value ]
    end

    def validate value, &block
      # is it okay to set this?
      case @match
      when Regexp
        yield format_error(value) if !@match.match(value)
      when Proc
        yield format_error(value) if !@match.call.match(value)
      when Array
        if !@match.map(&:to_s).include? value
          yield "On #{@name}, '#{value}' should be one of #{@match.join(", ")}."
        end
      end
    end

    def eager
      nil
    end

    def update record, new_value
      record.set({ @name => new_value })
    end

    def read_only?
      @readonly
    end

    def shown?
      !@hide
    end

    def tab_column?
      shown?
    end

    def schema_ok?
      schema.has_key?(column_name)
    end

    def schema_unchanged? 
      schema[column_name][:db_type].to_sym == literal_type
    end

    def needs_column?
      true
    end

    def column_name
      @name
    end


    def display_name
      @display_name || name.to_s.split(/_/).map(&:capitalize).join(' ')
    end

    def migration(mig)
      [ 
        mig.column_entry(@name, type),
        @unique && mig.unique_entry(@name),
        @index && mig.index_entry(@name)
      ].compact
    end

    def literal_type
      if @type == DateTime
        :"timestamp without time zone"
      else
        Magma.instance.db.cast_type_literal(@type)
      end
    end

    def update_link record, link
    end

    private
    def schema
      @model.schema
    end

    def format_error value
      if @format_hint
        "On #{@name}, '#{value}' should be like '#{@format_hint}'."
      else
        "On #{@name}, '#{value}' is improperly formatted."
      end
    end

    def set_options opts
      opts.each do |opt,value|
        if self.class.options.include? opt
          instance_variable_set("@#{opt}", value)
        end
      end
    end
  end
end

require_relative 'attributes/link'
require_relative 'attributes/child'
require_relative 'attributes/collection'
require_relative 'attributes/document'
require_relative 'attributes/foreign_key'
require_relative 'attributes/image'
require_relative 'attributes/table'
