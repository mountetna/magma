Sequel.migration do
  change do
    alter_table(:labors__labors) do
      add_column :year, DateTime
    end
  end
end
