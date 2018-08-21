class Magma
  class Migration
    class << self
      def create(model)
        puts model.table_name
        if Magma.instance.db.table_exists?(model.table_name)
          return Magma::UpdateMigration.new(model)
        else
          return Magma::CreateMigration.new(model)
        end
      end
    end

    def initialize(model)
      @model = model
      @changes = {}
    end

    def change(key, lines)
      @changes[key] ||= []
      @changes[key].concat lines
    end

    def empty?
      @changes.empty?
    end

    def to_s
      @changes.map do |key,lines|
        str = SPC*2 + key + ' do' + "\n"
        lines.each do |line|
          str += SPC*3 + line + "\n"
        end
        str += SPC*2 + 'end' + "\n"
        str
      end.join('').chomp
    end

    private

    SPC='  '

    def namespaced_table_name(model_name)
      project_name, table_name = model_name.split(/::/).map(&:snake_case)
      table_name = table_name.plural
      "Sequel[:#{project_name}][:#{table_name}]"
    end
  end
  class CreateMigration < Migration
    def initialize(model)
      super
      tlb_nm = "create_table(#{namespaced_table_name(model.name)})"
      change(tlb_nm, ['primary_key :id']+new_attributes)
    end

    def new_attributes
      @model.attributes.map do |name,att|
        next unless att.needs_column?
        att.migration(self)
      end.compact.flatten
    end

    def foreign_key_entry(column_name, foreign_table)
      table = "[:#{foreign_table.table.to_s}][:#{foreign_table.column.to_s}]"
      "foreign_key :#{column_name}, Sequel#{table}"
    end

    def column_entry name, type
      "#{type.name} :#{name}"
    end

    def unique_entry name
      "unique :#{name}"
    end

    def index_entry column
      if column.is_a? Array
        "index [#{column.map{|c| ":#{c}"}.join(", ")}]"
      else
        "index :#{column}"
      end
    end
  end

  class UpdateMigration < Migration
    def initialize model
      super
      change("alter_table(:#{model.table_name})", missing_attributes) unless missing_attributes.empty?

      change("alter_table(:#{model.table_name})", removed_attributes) unless removed_attributes.empty?

      change("alter_table(:#{model.table_name})", changed_attributes) unless changed_attributes.empty?
    end

    def foreign_key_entry(column_name, foreign_table)
      table = "[:#{foreign_table.table.to_s}][:#{foreign_table.column.to_s}]"
      "add_foreign_key :#{column_name}, Sequel#{table}"
    end

    def column_type_entry name, type
      "set_column_type :#{name}, #{type}"
    end

    def column_entry name, type
      "add_column :#{name}, #{type}"
    end

    def remove_column_entry name
      "drop_column :#{name}"
    end

    def unique_entry name
      "add_unique_constraint :#{name}"
    end

    def index_entry column
      if column.is_a? Array
        "add_index [#{column.map{|c| ":#{c}"}.join(", ")}]"
      else
        "add_index :#{column}"
      end
    end

    private

    def missing_attributes
      @model.attributes.map do |name,att|
        next if att.schema_ok?
        att.migration(self)
      end.compact.flatten
    end

    def changed_attributes
      @model.attributes.map do |name,att|
        next unless att.schema_ok?
        next unless att.needs_column?
        next if att.schema_unchanged?
        column_type_entry(att.column_name,
                          att.type)
      end.compact.flatten
    end

    def removed_attributes
      @model.schema.map do |name, db_opts|
        next if @model.attributes[name]
        next if @model.attributes[ name.to_s.sub(/_id$/,'').to_sym ]
        next if @model.attributes[ name.to_s.sub(/_type$/,'').to_sym ]
        next if db_opts[:primary_key]
        remove_column_entry(name)
      end.compact.flatten
    end
  end
end
