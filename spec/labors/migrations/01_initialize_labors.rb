Sequel.migration do
  change do
    create_table(:projects) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      String :name
      unique :name
    end
    create_table(:labors) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :project_id, :projects
      index :project_id
      String :name
      unique :name
      Integer :number
      TrueClass :completed
    end
    create_table(:monsters) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :labor_id, :labors
      index :labor_id
      String :name
      unique :name
      String :species
    end
    create_table(:prizes) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :labor_id, :labors
      index :labor_id
      String :name
      unique :name
      Integer :worth
    end
  end
end
