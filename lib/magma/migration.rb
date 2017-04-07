class Magma
  class Migration
    def initialize
      @changes = {}
    end

    def change key, lines
      @changes[key] ||= []
      @changes[key].concat lines
    end

    def to_s
      <<EOT
Sequel.migration do
  change do
#{changes}
  end
end
EOT
    end

    def suggest_migration model
      if Magma.instance.db.table_exists? model.table_name
        suggest_table_update model
      else
        suggest_table_creation model
      end
    end

    def set_column_type_entry name, type
      "set_column_type :#{name}, '#{type}'"
    end

    def column_entry name, type, mode
      case mode
      when :add
        "add_column :#{name}, #{type.name}"
      when :new
        "#{type.name} :#{name}"
      when :drop
        "drop_column :#{name}"
      end
    end

    def unique_entry name, mode
      case mode
      when :add
        "add_unique_constraint :#{name}"
      when :new
        "unique :#{name}"
      end
    end

    def index_entry column, mode
      case mode
      when :add
        if column.is_a? Array
          "add_index [#{column.map{|c| ":#{c}"}.join(", ")}]"
        else
          "add_index :#{column}"
        end
      when :new
        if column.is_a? Array
          "index [#{column.map{|c| ":#{c}"}.join(", ")}]"
        else
          "index :#{column}"
        end
      end
    end

    def foreign_key_entry name, foreign_model, mode
      case mode
      when :add
        "add_foreign_key :#{name}_id, :#{foreign_model.table_name}"
      when :new
        "foreign_key :#{name}_id, :#{foreign_model.table_name}"
      end
    end

    private
    SPC='  '

    def changes
      @changes.map do |key,lines|
        str = SPC*2 + key + ' do' + "\n"
        lines.each do |line|
          str += SPC*3 + line + "\n"
        end
        str += SPC*2 + 'end' + "\n"
        str
      end.join('').chomp
    end

    def suggest_table_creation model
      change "create_table(:#{model.table_name})", [ "primary_key :id" ] + suggest_new_attributes(model)
    end
    
    def suggest_new_attributes model
      model.attributes.map do |name,att|
        next unless att.needs_column?
        att.entry self, :new
      end.compact.flatten
    end
    
    def suggest_table_update model
      missing = suggest_missing_attributes model
      change "alter_table(:#{model.table_name})", missing unless missing.empty?

      removed = suggest_removed_attributes model
      change "alter_table(:#{model.table_name})", removed unless removed.empty?

      changed = suggest_changed_attributes model
      change "alter_table(:#{model.table_name})", changed unless changed.empty?
    end

    def suggest_missing_attributes model
      model.attributes.map do |name,att|
        next if att.schema_ok?
        att.entry self, :add
      end.compact.flatten
    end
    
    def suggest_removed_attributes model
      model.schema.map do |name, db_opts|
        next if model.attributes[name]
        next if model.attributes[ name.to_s.sub(/_id$/,'').to_sym ]
        next if model.attributes[ name.to_s.sub(/_type$/,'').to_sym ]
        next if db_opts[:primary_key]
        column_entry name, nil, :drop
      end.compact.flatten
    end

    # the attribute exists, it just has the wrong datatype.
    def suggest_changed_attributes model
      model.attributes.map do |name,att|
        next if att.needs_column?
        next if att.schema_unchanged?
        set_column_type_entry att.column_name, att.literal_type
      end.compact.flatten
    end
  end
end
