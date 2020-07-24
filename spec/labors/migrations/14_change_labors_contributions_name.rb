Sequel.migration do
  change do
    alter_table(Sequel[:labors][:labors]) do
      rename_column :contributions, :old_contributions
    end
  end
end
