Sequel.migration do
  change do
    alter_table(Sequel[:labors][:habitats]) do
      add_foreign_key :project_id, Sequel[:labors][:projects]
      add_index :project_id
    end
  end
end
