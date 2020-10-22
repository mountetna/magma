Sequel.migration do
  change do
    create_table(Sequel[:labors][:monster_pools]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      String :name
    end
    alter_table(Sequel[:labors][:monsters]) do
      add_foreign_key :monster_pool_id, Sequel[:labors][:monster_pools]
    end
  end
end
