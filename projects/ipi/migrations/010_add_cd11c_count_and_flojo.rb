Sequel.migration do
  change do
    alter_table(:dc_stains) do
      add_column :cd11c_count, Integer
    end
    alter_table(:patients) do
      add_column :flojo_file, String
    end
  end
end
