Sequel.migration do
  up do
    alter_table(:attributes) do
      add_column :attribute_group, String
    end
  end

  down do
    alter_table(:attributes) do
      drop_column :attribute_group
    end
  end
end
