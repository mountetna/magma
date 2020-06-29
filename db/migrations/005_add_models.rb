Sequel.migration do
  change do
    create_table(:models) do
      String :project_name, null: false
      String :model_name, null: false
      column :dictionary, :json
      DateTime :created_at
      DateTime :updated_at

      index [:project_name, :model_name], unique: true
    end
  end
end
