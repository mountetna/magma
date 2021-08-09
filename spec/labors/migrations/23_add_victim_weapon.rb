Sequel.migration do
  change do
    alter_table(Sequel[:labors][:victims]) do
      add_column :weapon, String
    end
  end
end
