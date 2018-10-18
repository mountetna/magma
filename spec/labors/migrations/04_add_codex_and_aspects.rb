Sequel.migration do
  change do
    create_table(Sequel[:labors][:codices]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :project_id, Sequel[:labors][:projects]
      index :project_id
      String :monster
      String :aspect
      String :tome
      json :lore
    end
    create_table(Sequel[:labors][:aspects]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      foreign_key :monster_id, Sequel[:labors][:monsters]
      index :monster_id
      String :name
      String :source
      String :value
    end
  end
end
