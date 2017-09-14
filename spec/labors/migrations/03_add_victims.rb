Sequel.migration do
  change do
    create_table(:labors__victims) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :monster_id, :labors__monsters
      index :monster_id
      String :name
      unique :name
      String :country
    end
  end
end
