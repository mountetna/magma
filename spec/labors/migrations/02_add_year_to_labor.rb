Sequel.migration do
  change do
    alter_table(Sequel[:labors][:labors]) do
      add_column :year, DateTime
    end
  end
end
