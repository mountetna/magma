Sequel.migration do
  change do
    create_table(:labors__projects) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      String :name
      unique :name
    end
    create_table(:labors__labors) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :project_id, :labors__projects
      index :project_id
      String :name
      unique :name
      Integer :number
      TrueClass :completed
    end
    create_table(:labors__monsters) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :labor_id, :labors__labors
      index :labor_id
      String :name
      unique :name
      String :species
    end
    create_table(:labors__prizes) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :labor_id, :labors__labors
      index :labor_id
      String :name
      unique :name
      Integer :worth
    end
  end
end
