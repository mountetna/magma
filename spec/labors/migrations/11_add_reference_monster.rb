Sequel.migration do
    change do
      alter_table(Sequel[:labors][:monsters]) do
        add_foreign_key :reference_monster_id, Sequel[:labors][:monsters]
      end
    end
  end
