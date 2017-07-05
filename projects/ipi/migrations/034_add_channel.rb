Sequel.migration do
  change do
    create_table(:channels) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :patient_id, :patients
      String :antibody
      String :fluor
      Integer :number
    end
  end
end
