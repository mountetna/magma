Sequel.migration do
  change do
    alter_table(:attributes) do
      add_column :type, String
      add_column :hidden, "boolean", default: "false"
      add_column :read_only, "boolean", default: "false"
      add_column :unique, "boolean", default: "false"
      add_column :index, "boolean", default: "false"
      add_column :loader, String
      add_column :restricted, "boolean", default: "false"
    end
  end
end
