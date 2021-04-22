Sequel.migration do
  change do
    create_table(Sequel[:labors][:characteristics]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :labor_id, Sequel[:labors][:labors]
      index :labor_id
      String :name
      String :value
    end
  end
end
