Sequel.migration do
  change do
    create_table(Sequel[:example][:example_projects]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      String :description
      String :name
      unique :name
    end

    create_table(Sequel[:example][:example_patients])
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      String :notes
      String :physician
    end
  end
end
