Sequel.migration do
  change do
    alter_table(Sequel[:labors][:victims]) do
      add_column :restricted, TrueClass
    end
  end
end
