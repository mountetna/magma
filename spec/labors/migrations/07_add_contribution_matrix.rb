Sequel.migration do
  change do
    alter_table(Sequel[:labors][:labors]) do
      add_column :contributions, :json
    end
  end
end
