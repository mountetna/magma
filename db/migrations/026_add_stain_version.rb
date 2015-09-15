Sequel.migration do
  change do
    alter_table(:patients) do
      add_column :stain_version, String
    end
  end
end
