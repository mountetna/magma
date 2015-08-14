Sequel.migration do
  change do
    create_table(:populations) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :sample_id, :samples
      foreign_key :population_id, :populations
      String :name
      String :stain
      Integer :count
    end
    create_table(:mfis) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :population_id, :populations
      String :name
      String :fluor
      Float :value
    end
  end
end
