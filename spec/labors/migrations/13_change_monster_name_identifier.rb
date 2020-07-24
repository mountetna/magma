Sequel.migration do
  change do
    alter_table(Sequel[:labors][:monsters]) do
      rename_column :name, :old_name
    end
  end
end
