class Magma
  class Migration
    class << self
      def table_name(model)
        "Sequel[:#{model.project_name}][:#{model.implicit_table_name}]"
      end
      def create(model)
        #puts table_name(model)
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
        [
          space("#{key} do", 2),
          lines.map do |line|
            space(line,3)
          end,
          space('end',2)
        ].flatten.join("\n")
      end.join("\n").chomp
    end

    private

    SPC='  '
    def space(txt, pad)
      "#{SPC*pad}#{txt}"
    end

  end
  class CreateMigration < Migration
    def initialize(model)
      super
      tlb_nm = "create_table(#{Magma::Migration.table_name(model)})"
      change(tlb_nm, ['primary_key :id']+new_attributes)
    end

    def new_attributes
      @model.attributes.map do |name,att|
        next unless att.needs_column?
        att.migration(self)
      end.compact.flatten
    end

    class Entry
    end

    def foreign_key_entry column_name, foreign_model
      "foreign_key :#{column_name}, #{Magma::Migration.table_name(foreign_model)}"
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
      change("alter_table(#{Magma::Migration.table_name(model)})", missing_attributes) unless missing_attributes.empty?

      change("alter_table(#{Magma::Migration.table_name(model)})", removed_attributes) unless removed_attributes.empty?

      change("alter_table(#{Magma::Migration.table_name(model)})", changed_attributes) unless changed_attributes.empty?
    end

    def foreign_key_entry column_name, foreign_model
      "add_foreign_key :#{column_name}, #{Magma::Migration.table_name(foreign_model)}"
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
