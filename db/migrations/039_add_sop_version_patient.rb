Sequel.migration do
  change do
    alter_table(:patients) do
      add_column :sop_version, String
    end
  end
end
