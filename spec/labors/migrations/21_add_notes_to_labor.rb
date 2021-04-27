Sequel.migration do
  change do
    alter_table(Sequel[:labors][:labors]) do
      add_column :notes, String
    end
  end
end
