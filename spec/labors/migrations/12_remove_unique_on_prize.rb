Sequel.migration do
    change do
      alter_table(Sequel[:labors][:prizes]) do
        drop_constraint :prizes_name_key
      end
    end
  end
