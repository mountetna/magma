Sequel.migration do
  change do
    alter_table(:nktb_stains) do
      add_column :facs_file, String
    end
    alter_table(:sort_stains) do
      add_column :facs_file, String
    end
    alter_table(:samples) do
      add_column :flojo_file, String
    end
    alter_table(:treg_stains) do
      add_column :facs_file, String
    end
  end
end
