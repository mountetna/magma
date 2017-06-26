Sequel.migration do
  change do
    alter_table(:patients) do
      add_column :processor, String
    end
  end
end
