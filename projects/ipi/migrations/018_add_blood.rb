Sequel.migration do
  change do
    alter_table(:patients) do
      add_column :received_blood, TrueClass
    end
  end
end
