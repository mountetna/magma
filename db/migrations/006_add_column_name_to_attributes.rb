Sequel.migration do
  up do
    alter_table(:attributes) do
      add_column :column_name, String
    end

    Magma.instance.db.execute("UPDATE attributes SET column_name=attribute_name")

    alter_table(:attributes) do
      set_column_not_null :column_name
      drop_index [:project_name, :model_name, :attribute_name]
      add_index [:project_name, :model_name, :attribute_name, :column_name], unique: true
    end
  end

  down do
    alter_table(:attributes) do
      drop_index [:project_name, :model_name, :attribute_name, :column_name]
      drop_column :column_name
      add_index [:project_name, :model_name, :attribute_name], unique: true
    end
  end
end
