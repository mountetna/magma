Sequel.migration do
  change do
    create_table(Sequel[:labors][:habitats]) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      String :name
    end
    alter_table(Sequel[:labors][:monsters]) do
      add_foreign_key :habitat_id, Sequel[:labors][:habitats]
    end
  end
end
