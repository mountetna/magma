Sequel.migration do
  change do
    alter_table(Sequel[:labors][:characteristics]) do
      rename_column :value, :old_value
    end
  end
end
