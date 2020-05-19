Sequel.migration do
  up do
    add_column :attributes, :link_model_name, String
  end

  down do
    drop_column :attributes, :link_model_name
  end
end
