Sequel.migration do
  change do
    alter_table(:populations) do
      add_column :ancestry, String
      drop_column :population_id
    end
  end
end
