Sequel.migration do
  change do
    create_table(Sequel[:labors][:projects]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      String :name
      unique :name
    end

    create_table(Sequel[:labors][:labors]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :project_id, Sequel[:labors][:projects]
      index :project_id
      String :name
      unique :name
      Integer :number
      TrueClass :completed
    end

    create_table(Sequel[:labors][:monsters]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :labor_id, Sequel[:labors][:labors]
      index :labor_id
      String :name
      unique :name
      String :species
    end

    create_table(Sequel[:labors][:prizes]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :labor_id, Sequel[:labors][:labors]
      index :labor_id
      String :name
      unique :name
      Integer :worth
    end
  end
end
