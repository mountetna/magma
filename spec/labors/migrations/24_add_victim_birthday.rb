Sequel.migration do
  change do
    alter_table(Sequel[:labors][:victims]) do
      add_column :birthday, DateTime
    end
  end
end
