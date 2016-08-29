Sequel.migration do
  change do
    create_table(:stain_panels) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :patient_id, :patients
      String :name
    end
    alter_table(:channels) do
      add_foreign_key :stain_panel_id, :stain_panels
      drop_column :patient_id
    end
  end
end
