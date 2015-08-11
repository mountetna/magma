Sequel.migration do
  change do
    alter_table(:patients) do
      add_column :clinical_id, Integer
      add_column :clinical_type, String
      add_index [:clinical_id, :clinical_type]
    end
  end
end
