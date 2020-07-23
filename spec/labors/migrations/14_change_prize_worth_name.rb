Sequel.migration do
  change do
    alter_table(Sequel[:labors][:prizes]) do
      rename_column :worth, :old_worth
    end
  end
end
