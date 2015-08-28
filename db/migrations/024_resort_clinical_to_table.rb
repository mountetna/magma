Sequel.migration do
  change do
    create_table(:clinicals) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      String :clinical_name
      unique :clinical_name
      String :race_ethnicity
      String :sex
      Integer :age_at_diagnosis
      String :stage
      String :grade
      String :history
    end
    create_table(:treatments) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :clinical_id, :clinicals
      String :type
      String :regimen
      DateTime :start
      DateTime :stop
    end
    create_table(:outcomes) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :clinical_id, :clinicals
      String :name
      String :value
    end
    create_table(:parameters) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :clinical_id, :clinicals
      String :name
      String :description
      String :type
      String :value
    end
    drop_table(:clinical_breasts, :clinical_hnscs, :clinical_melanomas, :clinical_colorectals)
  end
end
