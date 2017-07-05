Sequel.migration do
  change do
    alter_table(:projects) do
      add_column :description, String
    end
  end
end
