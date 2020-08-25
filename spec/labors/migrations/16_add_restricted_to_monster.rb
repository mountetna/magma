Sequel.migration do
  change do
    alter_table(Sequel[:labors][:monsters]) do
      add_column :restricted, TrueClass
    end
  end
end
