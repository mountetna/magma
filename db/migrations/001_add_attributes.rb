Sequel.migration do
  change do
    create_table(:attributes) do
      String :project_name
      String :model_name
      String :attribute_name
      String :desc
      String :display_name
      String :match
      String :format_hint
      DateTime :created_at
      DateTime :updated_at

      index [:project_name, :model_name, :attribute_name], unique: true
    end
  end
end
