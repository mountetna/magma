Sequel.migration do
  up do
    add_column :attributes, :link_model, String
  end

  down do
    drop_column :attributes, :link_model
  end
end
