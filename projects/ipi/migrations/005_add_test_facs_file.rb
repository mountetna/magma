Sequel.migration do
  change do
    alter_table(:dc_stains) do
      add_column :facs_file, String
    end
  end
end
