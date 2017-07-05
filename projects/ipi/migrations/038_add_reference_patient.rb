Sequel.migration do
  change do
    alter_table(:patients) do
      add_foreign_key :reference_patient_id, :patients
    end
  end
end
